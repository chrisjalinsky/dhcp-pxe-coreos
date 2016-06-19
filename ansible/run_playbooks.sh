#!/bin/bash

# Installs DNS in the environment, and is not necessary if DNS already exists
ansible-playbook provision_core_servers.yaml -i inventory.py >>./install.out 2>&1

# Updates the cluster node's resolv.conf to point to the previous playbook's DNS server(s), this is not necessary if DNS resolution already exists
if [ $? -eq 0 ]; then
  ansible-playbook update_resolv.yaml -i inventory.py >>./install.out 2>&1
fi

# Install tftpd pxe server
if [ $? -eq 0 ]; then
  ansible-playbook provision_tftpd_server_for_bootcfg.yaml -i inventory.py >>./install.out 2>&1
  
  #or run for an apache server and separate templates. You need to download the netboot.tar.gz:
  #ansible-playbook provision_tftpd_server.yaml -i inventory.py >>./install.out 2>&1
fi

# Install bootcfg server for coreos baremetal bootcfg api pxe boot server. The get-coreos.sh distro download is several hundred MBs.
if [ $? -eq 0 ]; then
  ansible-playbook provision_bootcfg_server.yaml -i inventory.py >>./install.out 2>&1
fi

# Install dhcp server
if [ $? -eq 0 ]; then
  ansible-playbook provision_dhcp_server_for_bootcfg.yaml -i inventory.py >>./install.out 2>&1
  
  #or run:
  #ansible-playbook provision_dhcp_server.yaml -i inventory.py >>./install.out 2>&1

fi