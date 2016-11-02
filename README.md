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

The ARM template is designed to prompt for the information needed to create the CA, Server and Client certificates and key-pairs. You can also select if you wish to redirect all traffic via the VPN server.

This template is work in progress to more features. Please drop me a note with your suggestions to improve this template.

