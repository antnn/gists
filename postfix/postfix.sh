#!/bin/bash
#RUNS on local machine combined config with opendkim and openarc
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
#!/bin/bash
SERVER_NAME="mail.valishin.ru"
CLIENT_IP="192.168.244.2"
SERVER_IP="192.168.244.1"
TUN_NUM="5"
TUN_DEVICE="tun$TUN_NUM"

# SSH command
ssh -i /id_rsa -o PermitLocalCommand=yes \
    -o LocalCommand="
        sudo ip addr add $CLIENT_IP peer $SERVER_IP/31 dev $TUN_DEVICE;
        sudo ip link set dev $TUN_DEVICE up;
        sudo ip route add default via $SERVER_IP dev $TUN_DEVICE metric 60
    " \
    -o ServerAliveInterval=60 \
    -o ExitOnForwardFailure=yes \
    -o Tunnel=point-to-point \
    -w $TUN_NUM:$TUN_NUM \
    $SERVER_NAME \
    "
    # Dynamically determine the default network interface on the server
    DEFAULT_IFACE=\$(ip route | awk '/default/ {print \$5; exit}')

    sudo ip addr add $SERVER_IP peer $CLIENT_IP/31 dev $TUN_DEVICE;
    sudo ip link set dev $TUN_DEVICE up;
    sudo iptables -t nat -D POSTROUTING -s $CLIENT_IP/31 -o \$DEFAULT_IFACE -j MASQUERADE;
    sudo iptables -t nat -A POSTROUTING -s $CLIENT_IP/31 -o \$DEFAULT_IFACE -j MASQUERADE;
    echo $TUN_DEVICE ready, NAT interface: \$DEFAULT_IFACE
    "
EOF
