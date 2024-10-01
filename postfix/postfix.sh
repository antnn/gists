#!/bin/bash
#RUNS on local machine
sudo tee /etc/opendkim.conf << EOF
AutoRestart yes
AutoRestartRate 5/1H
SignatureAlgorithm rsa-sha256
UserID opendkim


UMask                   002
# OpenDKIM user
UserID                  opendkim

KeyTable                refile:/etc/opendkim/key.table
SigningTable            refile:/etc/opendkim/signing.table

# Hosts to ignore when verifying signatures
ExternalIgnoreList      /etc/opendkim/trusted.hosts
InternalHosts           /etc/opendkim/trusted.hosts


Mode                    sv
Canonicalization        relaxed/relaxed


# Always oversign From (sign using actual From and a null From to prevent
# malicious signatures header fields (From and/or others) between the signer
# and the verifier.  From is oversigned by default in the Debian package
# because it is often the identity key used by reputation systems and thus
# somewhat security sensitive.
OversignHeaders         From

Socket inet:8891@localhost
EOF

#####
sudo tee /etc/openarc.conf << EOF
PidFile /run/openarc/openarc.pid
UserID  openarc:openarc
Socket  inet:8892@localhost

Mode                    sv
Canonicalization        relaxed/relaxed
Domain                  valishin.ru
Selector                marc
KeyFile                 /etc/openarc/keys/marc.private
SignHeaders to,subject,message-id,date,from,mime-version,dkim-signature,arc-authentication-results
EOF

#####
sudo tee -a /etc/postfix/main.cf << EOF
myhostname = mail.valishin.ru
mydomain = \$myhostname
myorigin = \$mydomain
smtp_helo_name = \$mydomain
inet_interfaces = all
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
smtpd_banner = \$myhostname ESMTP \$mail_name
smtp_tls_security_level = encrypt
smtp_tls_loglevel = 1
maillog_file = /var/log/postfix.log
milter_protocol = 2
milter_default_action = accept
smtpd_milters = inet:localhost:8891
        inet:localhost:8892
non_smtpd_milters = \$smtpd_milters
internal_mail_filter_classes = bounce
EOF

#####
sudo tee tun.sh << 'EOF'
# Resolve the IP address and set it back to HOST
HOST="CHANGE_HOST"
RESOLVED_IP=$(dig +short $HOST)
if [ -n "$RESOLVED_IP" ]; then
    HOST=$RESOLVED_IP
else
    echo "Failed to resolve IP for $HOST"
    exit 1
fi

HOST_PORT=22
export TUN_LOCAL=0   # tun device number here.
export TUN_REMOTE=0  # tun device number there
export IP_LOCAL=192.168.111.2 # IP Address for tun here
export IP_REMOTE=192.168.111.1 # IP Address for tun there.
export IP_MASK=30 # Mask of the ips above.
export NET_REMOTE=192.168.0.0/16 # Network on the other side of the tunnel
export NET_LOCAL=192.168.8.0/24  # Network on this side of the tunnel

echo "Starting VPN tunnel ..."
#ip route add $HOST via 192.168.113.173 dev eno0
ssh -i id_ssh \
       -w ${TUN_LOCAL}:${TUN_REMOTE} -f ${HOST} -p ${HOST_PORT} "\
       sysctl -w net.ipv4.ip_forward=1 ; \
       ip addr add ${IP_REMOTE}/${IP_MASK} dev tun${TUN_REMOTE} ; \
       ip link set tun${TUN_REMOTE} up ; \
       iptables -t filter -F FORWARD ; \
       iptables -t nat -F POSTROUTING ; \
       iptables -t filter -I FORWARD -j ACCEPT ; \
       iptables -t nat -I POSTROUTING -j MASQUERADE ; \
       iptables -t mangle -A PREROUTING -i tun0 -j TTL --ttl-set 64 ; \
       true; \
       while true; do sleep 10000000000 ; done;
" &
sleep 3
ip addr add ${IP_LOCAL}/${IP_MASK} dev tun${TUN_LOCAL}
ip link set tun${TUN_LOCAL} up
ip r add $HOST via 192.168.1.2 dev eno1
ip r del default
ip route add default via ${IP_REMOTE}  dev tun0
EOF
