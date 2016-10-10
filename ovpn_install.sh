#!/bin/bash

userPassword=$1
userCountry=$2
userProvince=$3
userCity=$4
userOrg=$5
userEmail=$6
userOU=$7
vpnProto=$8
vpnPort=$9
vpnAllTraffic=$10
userKeyName=server

echo Installing openvpn and EasyRSA packages
sudo apt-get update
sudo apt-get install openvpn easy-rsa <<EOF
y
EOF

echo Creating CA directory structure
make-cadir ~/openvpn-ca
cd ~/openvpn-ca

echo Modifying the values to be populated in the Certificate
sed -i "s/`grep KEY_COUNTRY vars`/export KEY_COUNTRY=\"$userCountry\"/g" vars
sed -i "s/`grep KEY_PROVINCE vars`/export KEY_PROVINCE=\"$userProvince\"/g" vars
sed -i "s/`grep KEY_CITY vars`/export KEY_CITY=\"$userCity\"/g" vars
sed -i "s/`grep KEY_ORG vars`/export KEY_ORG=\"$userOrg\"/g" vars
sed -i "s/`grep KEY_EMAIL vars`/export KEY_EMAIL=\"$userEmail\"/g" vars
sed -i "s/`grep KEY_OU vars`/export KEY_OU=\"$userOU\"/g" vars
sed -i "s/`grep KEY_NAME vars`/export KEY_NAME=\"$userKeyName\"/g" vars

echo Sourcing the vars file
cd ~/openvpn-ca
. ./vars

echo Building root CA
./clean-all
./build-ca <<EOF








EOF

echo Generating server certificate
./build-key-server server <<EOF










y
y
EOF

echo Building the DH keys
./build-dh
mkdir -p ~/openvpn-ca/keys

echo Generating HMAC signature
openvpn --genkey --secret keys/ta.key

echo Generating Client Certificate and Key Pair
cd ~/openvpn-ca
. ./vars
./build-key client <<EOF










y
y
EOF

echo Copying files to the openvpn directory
cd ~/openvpn-ca/keys
sudo cp ca.crt ca.key server.crt server.key ta.key dh2048.pem /etc/openvpn

echo Copying sample server configuration to /etc/openvpn
gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz | sudo tee /etc/openvpn/server.conf >/dev/null

echo Determining my public ip address
mypublicip=`dig +short myip.opendns.com @resolver1.opendns.com`

echo Modifying the server configuration
sudo sed -i "s/`grep tls-auth /etc/openvpn/server.conf`/tls-auth ta.key 0 \nkey-direction 0/g" /etc/openvpn/server.conf
sudo sed -i "s/`grep \"cipher AES-128-CBC\" /etc/openvpn/server.conf`/cipher AES-128-CBC \nauth SHA256/g" /etc/openvpn/server.conf
sudo sed -i "s/`grep \"user nobody\" /etc/openvpn/server.conf`/user nobody/g" /etc/openvpn/server.conf
sudo sed -i "s/`grep \"group nogroup\" /etc/openvpn/server.conf`/group nogroup/g" /etc/openvpn/server.conf
sudo sed -i "s/`grep \"duplicate-cn\" /etc/openvpn/server.conf`/duplicate-cn/g" /etc/openvpn/server.conf
if [ "$vpnAllTraffic" = "yes" ]; then
    sudo sed -i "s/`grep redirect-gateway /etc/openvpn/server.conf`/push \"redirect-gateway def1 bypass-dhcp\"/g" /etc/openvpn/server.conf
    sudo sed -i "s/`grep -m1 dhcp-option /etc/openvpn/server.conf`/push \"dhcp-option DNS 208.67.222.222\"\npush \"dhcp-option DNS 208.67.220.220\"/g" /etc/openvpn/server.conf
fi

echo Modifying port and protocol to be used
sudo sed -i "s/`grep ^port /etc/openvpn/server.conf`/port $vpnPort/g" /etc/openvpn/server.conf
sudo sed -i "s/`grep ^proto /etc/openvpn/server.conf`/proto $vpnProto/g" /etc/openvpn/server.conf

echo Configuring IP forwarding
sudo sed -i "s/`grep net.ipv4.ip_forward /etc/sysctl.conf`/net.ipv4.ip_forward=1/g" /etc/sysctl.conf
sudo sysctl -p

echo Configuring UFW to allow traffic from OpenVPN clients
sudo sed -i "s/`sudo grep \*filter /etc/ufw/before.rules`/\*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -s 10.8.0.0\/8 -o `ip route|grep default|awk '{print $NF}'` -j MASQUERADE\nCOMMIT\n\*filter/g" /etc/ufw/before.rules

sudo sed -i "s/`grep DEFAULT_FORWARD_POLICY /etc/default/ufw`/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/g" /etc/default/ufw

echo Opening ports and enabling changes
sudo ufw allow $vpnPort/$vpnProto
sudo ufw allow OpenSSH
sudo ufw disable
sudo ufw enable <<EOF
y
EOF

echo Starting the OpenVPN service
sudo systemctl start openvpn@server
sudo grep "Initialization Sequence Completed" /var/log/syslog >/dev/null || (echo OpenVPN initialization failed)

echo Creating client configuration
mkdir -p ~/client-configs/files
chmod 700 ~/client-configs/files
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ~/client-configs/base.conf

sudo sed -i "s/`grep ^remote ~/client-configs/base.conf |grep -v remote-cert-tls`/remote $mypublicip $vpnPort/g" ~/client-configs/base.conf
sudo sed -i "s/`grep ^proto ~/client-configs/base.conf`/proto $vpnProto/g" ~/client-configs/base.conf
sudo sed -i "s/`grep user ~/client-configs/base.conf`/user nobody/g" ~/client-configs/base.conf
sudo sed -i "s/`grep group ~/client-configs/base.conf`/group nogroup/g" ~/client-configs/base.conf
sudo sed -i "s/`grep ^ca ~/client-configs/base.conf`/#ca ca.crt/g" ~/client-configs/base.conf
sudo sed -i "s/`grep ^cert ~/client-configs/base.conf`/#cert client.crt/g" ~/client-configs/base.conf
sudo sed -i "s/`grep ^key ~/client-configs/base.conf`/#key client.key/g" ~/client-configs/base.conf
sudo sed -i "s/`grep ^\;cipher ~/client-configs/base.conf`/cipher AES-128-CBC\nauth SHA256\nkey-direction 1/g" ~/client-configs/base.conf

echo Creating the client configuration file with embedded certs and keys
KEY_DIR=~/openvpn-ca/keys
OUTPUT_DIR=~/client-configs/files
BASE_CONFIG=~/client-configs/base.conf


cat ${BASE_CONFIG} <(echo -e '<ca>') ${KEY_DIR}/ca.crt <(echo -e '</ca>\n<cert>') ${KEY_DIR}/client.crt <(echo -e '</cert>\n<key>') ${KEY_DIR}/client.key <(echo -e '</key>\n<tls-auth>') ${KEY_DIR}/ta.key <(echo -e '</tls-auth>') > ${OUTPUT_DIR}/${HOSTNAME}-client.ovpn

echo "OpenVPN Server configuration completed. Client configuration file can be found at ${OUTPUT_DIR}"
