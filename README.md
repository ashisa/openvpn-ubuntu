<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fashisa%2Fopenvpn-ubuntu%2Fmaster%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

---
platforms: 16.04.0-LTS
Software: OpenVPN
author: Ashish Sahu
---

# ARM template to deploy and configure OpenVPN on Ubuntu 16.04.0-LTS automatically

This ARM template deploys a Ubuntu 16.04.0-LTS VM and configures the OpenVPN server automatically for you. The custom extension script also creates a client configuration file that can be download and used on  Linux, Mac and Windows machine using any OpenVPN-compatible client to connect to the Azure VNet.

While deploying this ARM template in your Azure subscription, you will to provide the following parameters -
+ Hostname - Will be used as the hostname of the VM
+ Admin User Name - This user will be provisioned on the VM
+ Admin Password - The password to be used for the admin user name
+ DNS Name - The DNS for the VM
+ Country Code - For the creation of the CA, Server and Client certificates
+ Province - Name of the province
+ City - The city name to be put on the certificates
+ Organization Name - You organization name
+ Email Id - to be put on the certificates
+ OU Name - The specific organizational unit the certificates will be issued for
+ OpenVPN Protocol - Select TCP or UDP as the protocol to be used for VPN connections to this VPN server
+ OpenVPN Port Number - Change this if you wish to configure OpenVPN to listen on a non-default portal
+ All Traffic - Select true if you wish to use this VM as a forward all VPN server. False, if you are deploying this VM to access your virtual network subnets using a VPN client
+ Subnets - Not used at the moment

Following is a cursory list of things that are executed by the custom extension script after the VM has been provisioned successfully -

1. Install OpenVPN and Easy-RSA
2. Use the values provided at the time of ARM template deployment to build a Certificate Authority on the VM. This CA will be used to generate the server and client certificates required for OpenVPN
3. Create Server and Client certificates and keys
4. Use server configuration templates and change the configuration based on the parameters defined at the time of creation
5. Enable IP forwarding and configure UFW to allow SSH and OpenVPN connections
6. Start the OpenVPN service on the host
7. Finally, create a client configuration file and embed the CA/Client certificates and keys in it

This custom extesion script takes a little over 8-minutes after the VM has been provisioned to configure a fully functioning OpenVPN server. Once the deployment is successful, you can copy the client configuration file using your favorite SCP client (I use pscp) using the following syntax -

```bash
pscp <admin user name>@<server public ip>:/etc/openvpn/client-configs/files/<hostname>-client.ovpn .
```

You can now import this client configuration file with your choice of OpenVPN client and connect from Windows, Mac or Linux machines.

Note: This template is work in progress to more features. Please drop me a note with your suggestions to improve this template.

