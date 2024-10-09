#!/bin/bash
#######
# REPRODUCTION FOR THE BUG 
# https://gitlab.freedesktop.org/NetworkManager/NetworkManager/-/issues/1641
# Relevant code? 
# https://gitlab.freedesktop.org/NetworkManager/NetworkManager/-/blob/bb6881f88c256a7f91ed4ad78f76f0b6c86a681a/src/core/vpn/nm-vpn-connection.c#L1215
#######
# Set variables
IMAGE_NAME="sstp-server-test"
SERVER_PASSWORD=ServerPassword123
HUB_NAME=myhub
HUB_PASSWORD=HubPassword123
VPN_USER1=vpnuser1
VPN_PASSWORD1=UserPassword1
IPSEC_PSK=PreSharedKey123
VPN_CONNECTION_NAME="TEST SSTP"

# Create a temporary Dockerfile
cat << EOF > Dockerfile.tmp
FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Download and install SoftEther VPN
WORKDIR /opt
RUN wget https://www.softether-download.com/files/softether/v4.42-9798-rtm-2023.06.30-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.42-9798-rtm-2023.06.30-linux-x64-64bit.tar.gz \
    && tar xzvf softether-vpnserver-v4.42-9798-rtm-2023.06.30-linux-x64-64bit.tar.gz  \
    && cd vpnserver && make

# Create a script to initialize the VPN server
RUN echo '#!/bin/bash\n\
echo "Waiting for 30 seconds before starting the VPN server. Please assign VETH to the container"\n\
sleep 30\n\
echo "Starting VPN server..."\n\
/opt/vpnserver/vpnserver start\n\
sleep 5\n\
/opt/vpnserver/vpncmd /SERVER localhost /CMD ServerPasswordSet ${SERVER_PASSWORD}\n\
/opt/vpnserver/vpncmd /SERVER localhost /PASSWORD:${SERVER_PASSWORD} /CMD HubCreate ${HUB_NAME} /PASSWORD:${HUB_PASSWORD}\n\
/opt/vpnserver/vpncmd /SERVER localhost /PASSWORD:${SERVER_PASSWORD} /ADMINHUB:${HUB_NAME} /CMD UserCreate ${VPN_USER1} /GROUP:none /REALNAME:none /NOTE:none\n\
/opt/vpnserver/vpncmd /SERVER localhost /PASSWORD:${SERVER_PASSWORD} /ADMINHUB:${HUB_NAME} /CMD UserPasswordSet ${VPN_USER1} /PASSWORD:${VPN_PASSWORD1}\n\
/opt/vpnserver/vpncmd /SERVER localhost /PASSWORD:${SERVER_PASSWORD} /CMD ListenerCreate 443\n\
/opt/vpnserver/vpncmd /SERVER localhost /PASSWORD:${SERVER_PASSWORD} /CMD SstpEnable yes\n\
/opt/vpnserver/vpncmd /SERVER localhost /PASSWORD:${SERVER_PASSWORD} /CMD IPsecEnable /L2TP:yes /L2TPRAW:yes /ETHERIP:no /PSK:${IPSEC_PSK} /DEFAULTHUB:${HUB_NAME}\n\
/opt/vpnserver/vpncmd /SERVER localhost /PASSWORD:${SERVER_PASSWORD} /ADMINHUB:${HUB_NAME}  /CMD SecureNatEnable \n\
echo "VPN server initialization completed."\n\
handle_sigterm() { \n\
    echo "Received SIGTERM. Gracefully shutting down..."\n\
    exit 0\n\
}\n\
trap "handle_sigterm" SIGTERM\n\
while true; do sleep 1; done;\n\
' > /opt/init_vpn.sh && chmod +x /opt/init_vpn.sh

ENTRYPOINT ["/opt/init_vpn.sh"]
EOF


podman build --no-cache -t $IMAGE_NAME -f Dockerfile.tmp .
rm Dockerfile.tmp

CONTAINER_NAME="sstp_server"
podman run -d \
  --replace \
  --name $CONTAINER_NAME \
  $IMAGE_NAME

# Wait for the container to start
sleep 1

VETH_HOST="veth_host"
VETH_CONTAINER="veth_container"
CONTAINER_IP="172.20.0.2/24"
HOST_IP="172.20.0.1/24"

# Get the container's PID
CONTAINER_PID=$(podman inspect -f '{{.State.Pid}}' $CONTAINER_NAME)

# Create veth pair
sudo ip link add $VETH_HOST type veth peer name $VETH_CONTAINER

# Move one end of veth pair into container's network namespace
sudo ip link set $VETH_CONTAINER netns $CONTAINER_PID

# Configure host side of veth pair
sudo ip addr add $HOST_IP dev $VETH_HOST
sudo ip link set $VETH_HOST up

# Configure container side of veth pair
sudo nsenter -t $CONTAINER_PID -n ip addr add $CONTAINER_IP dev $VETH_CONTAINER
sudo nsenter -t $CONTAINER_PID -n ip link set $VETH_CONTAINER up

#echo Set the password for connection via gui if it is empty and set "Ignore certificate warnings"
nmcli connection add \
    type vpn \
    con-name "$VPN_CONNECTION_NAME" \
    ifname -- \
    vpn-type sstp \
    vpn.data "gateway = ${CONTAINER_IP%/*}, refuse-eap = yes, refuse-pap = yes, refuse-chap = yes, refuse-mschap = yes, require-mschap-v2 = yes, user = $VPN_USER1, ignore-cert-warn = yes" \
    vpn.secrets "password = $VPN_PASSWORD1"


echo waiting for container to start vpn server
sleep 40


echo "*************************"
echo BEFORE connection
ip route
echo "*************************"

nmcli connection up "$VPN_CONNECTION_NAME"

sleep 10

echo "*************************"
echo AFTER connection
ip route
echo "*************************"

cleanup() {
    # Remove VPN connection
    nmcli connection down "$VPN_CONNECTION_NAME" 2>/dev/null
    nmcli connection delete "$VPN_CONNECTION_NAME" 2>/dev/null

    # Remove veth pair
    sudo ip link delete $VETH_HOST 2>/dev/null

    # Stop and remove the container
    podman stop $CONTAINER_NAME 2>/dev/null
    podman rm $CONTAINER_NAME 2>/dev/null

}
cleanup
