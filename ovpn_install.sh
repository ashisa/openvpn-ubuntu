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
workingdir=/etc/openvpn

echo Installing openvpn and EasyRSA packages
sudo apt-get update
sudo apt-get install openvpn easy-rsa <<EOF
y
EOF

echo Creating CA directory structure
sudo make-cadir $workingdir/openvpn-ca
cd $workingdir/openvpn-ca

echo Modifying the values to be populated in the Certificate
sed -i "s/`grep KEY_COUNTRY vars`/export KEY_COUNTRY=\"$userCountry\"/g" $workingdir/openvpn-ca/vars
sed -i "s/`grep KEY_PROVINCE vars`/export KEY_PROVINCE=\"$userProvince\"/g" $workingdir/openvpn-ca/vars
sed -i "s/`grep KEY_CITY vars`/export KEY_CITY=\"$userCity\"/g" $workingdir/openvpn-ca/vars
sed -i "s/`grep KEY_ORG vars`/export KEY_ORG=\"$userOrg\"/g" $workingdir/openvpn-ca/vars
sed -i "s/`grep KEY_EMAIL vars`/export KEY_EMAIL=\"$userEmail\"/g" $workingdir/openvpn-ca/vars
sed -i "s/`grep KEY_OU vars`/export KEY_OU=\"$userOU\"/g" $workingdir/openvpn-ca/vars
sed -i "s/`grep KEY_NAME vars`/export KEY_NAME=\"$userKeyName\"/g" $workingdir/openvpn-ca/vars

echo Sourcing the vars file
cd $workingdir/openvpn-ca
. ./vars

echo Building root CA
./clean-all
echo Building keys
./build-dh
echo Creating CA cert and key
./pkitool --initca
echo Creating Server cert and key
./pkitool --server server
echo Creating client cert and key
./pkitool client

echo Generating HMAC signature
sudo openvpn --genkey --secret $workingdir/openvpn-ca/keys/ta.key
sudo chmod 644 ./keys/.rnd

echo Copying files to the openvpn directory
cd $workingdir/openvpn-ca/keys
sudo cp ca.crt ca.key server.crt server.key ta.key dh2048.pem /etc/openvpn

echo Copying sample server configuration to /etc/openvpn
sudo gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz | sudo tee /etc/openvpn/server.conf >/dev/null

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
mkdir -p $workingdir/client-configs/files
sudo chmod 700 $workingdir/client-configs/files
sudo cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf $workingdir/client-configs/base.conf

sudo sed -i "s/`grep ^remote $workingdir/client-configs/base.conf |grep -v remote-cert-tls`/remote $mypublicip $vpnPort/g" $workingdir/client-configs/base.conf
sudo sed -i "s/`grep ^proto $workingdir/client-configs/base.conf`/proto $vpnProto/g" $workingdir/client-configs/base.conf
sudo sed -i "s/`grep user $workingdir/client-configs/base.conf`/user nobody/g" $workingdir/client-configs/base.conf
sudo sed -i "s/`grep group $workingdir/client-configs/base.conf`/group nogroup/g" $workingdir/client-configs/base.conf
sudo sed -i "s/`grep ^ca $workingdir/client-configs/base.conf`/#ca ca.crt/g" $workingdir/client-configs/base.conf
sudo sed -i "s/`grep ^cert $workingdir/client-configs/base.conf`/#cert client.crt/g" $workingdir/client-configs/base.conf
sudo sed -i "s/`grep ^key $workingdir/client-configs/base.conf`/#key client.key/g" $workingdir/client-configs/base.conf
sudo sed -i "s/`grep ^\;cipher $workingdir/client-configs/base.conf`/cipher AES-128-CBC\nauth SHA256\nkey-direction 1/g" $workingdir/client-configs/base.conf

echo Creating the client configuration file with embedded certs and keys
KEY_DIR=$workingdir/openvpn-ca/keys
OUTPUT_DIR=$workingdir/client-configs/files
BASE_CONFIG=$workingdir/client-configs/base.conf


sudo cat ${BASE_CONFIG} > ${OUTPUT_DIR}/${HOSTNAME}-client.ovpn
sudo echo -e '<ca>' >> ${OUTPUT_DIR}/${HOSTNAME}-client.ovpn
sudo cat ${KEY_DIR}/ca.crt >> ${OUTPUT_DIR}/${HOSTNAME}-client.ovpn
sudo echo -e '</ca>\n<cert>' >> ${OUTPUT_DIR}/${HOSTNAME}-client.ovpn
sudo cat ${KEY_DIR}/client.crt >> ${OUTPUT_DIR}/${HOSTNAME}-client.ovpn
sudo echo -e '</cert>\n<key>' >> ${OUTPUT_DIR}/${HOSTNAME}-client.ovpn
sudo cat ${KEY_DIR}/client.key >> ${OUTPUT_DIR}/${HOSTNAME}-client.ovpn
sudo echo -e '</key>\n<tls-auth>' >> ${OUTPUT_DIR}/${HOSTNAME}-client.ovpn
sudo cat ${KEY_DIR}/ta.key >> ${OUTPUT_DIR}/${HOSTNAME}-client.ovpn
sudo echo -e '</tls-auth>' >> ${OUTPUT_DIR}/${HOSTNAME}-client.ovpn

echo "OpenVPN Server configuration completed. Client configuration file can be found at ${OUTPUT_DIR}"
