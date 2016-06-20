#!/bin/bash

echo "Beginning Installation. The ansible playbook stderr/stdout will be appended to ./install.out"

# Installs DNS in the environment, and is not necessary if DNS already exists
echo "Starting core server playbook"
ansible-playbook provision_core_servers.yaml -i inventory.py >>./install.out 2>&1
echo "End core server playbook"

# Updates the cluster node's resolv.conf to point to the previous playbook's DNS server(s), this is not necessary if DNS resolution already exists
if [ $? -eq 0 ]; then
  echo "Starting update resolv playbook"
  ansible-playbook update_resolv.yaml -i inventory.py >>./install.out 2>&1
  echo "End update resolv playbook"
fi

# Install tftpd pxe server
if [ $? -eq 0 ]; then
  echo "Starting tftpd server playbook"
  ansible-playbook provision_tftpd_server_for_bootcfg.yaml -i inventory.py >>./install.out 2>&1
  echo "End tftpd server playbook"
  
  #or run for an apache server and separate templates. You need to download the netboot.tar.gz:
  #ansible-playbook provision_tftpd_server.yaml -i inventory.py >>./install.out 2>&1
fi

# Install bootcfg server for coreos baremetal bootcfg api pxe boot server. The get-coreos.sh distro download is several hundred MBs.
if [ $? -eq 0 ]; then
  echo "Starting bootcfg server playbook"
  ansible-playbook provision_bootcfg_server.yaml -i inventory.py >>./install.out 2>&1
  echo "End bootcfg server playbook"
fi

# Install dhcp server
if [ $? -eq 0 ]; then
  echo "Starting dhcp server playbook"
  ansible-playbook provision_dhcp_server_for_bootcfg.yaml -i inventory.py >>./install.out 2>&1
  echo "End dhcp server playbook"
  
  #or run:
  #ansible-playbook provision_dhcp_server.yaml -i inventory.py >>./install.out 2>&1

fi

## Sleep for 3 minutes while the Kubernetes cluster builds itself
#if [ $? -eq 0 ]; then
#  echo "Sleeping for 3 mins while Cluster builds..."
#  sleep 180
#  echo "Done sleeping..."
#fi
#
## Create Ingress Controller for Kubernetes
#if [ $? -eq 0 ]; then
#  echo "Starting Kubernetes Ingress controller creation playbook"
#  ansible-playbook provision_k8s_ingress_ctrl.yaml -i inventory.py >>./install.out 2>&1
#  echo "End kubernetes ingress ctrl playbook"
#  echo "Installation complete!"
#fi

