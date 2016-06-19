#!/bin/bash

# Installs DNS in the environment, and is not necessary if DNS already exists
ansible-playbook provision_core_servers.yaml -i inventory.py >>./install.out 2>&1

# Updates the cluster node's resolv.conf to point to the previous playbook's DNS server(s), this is not necessary if DNS resolution already exists
if [ $? -eq 0 ]; then
  ansible-playbook update_resolv.yaml -i inventory.py >>./install.out 2>&1
fi

# Install tftpd pxe server
if [ $? -eq 0 ]; then
  ansible-playbook provision_tftpd_server.yaml -i inventory.py >>./install.out 2>&1
  #or run:
  #ansible-playbook provision_tftpd_server_for_bootcfg.yaml -i inventory.py >>./install.out 2>&1
fi

# Install bootcfg server for coreos baremetal bootcfg api pxe boot server
if [ $? -eq 0 ]; then
  ansible-playbook provision_bootcfg_server.yaml -i inventory.py >>./install.out 2>&1
fi

# Install dhcp server
if [ $? -eq 0 ]; then
  ansible-playbook provision_dhcp_server.yaml -i inventory.py >>./install.out 2>&1
  #or run:
  #ansible-playbook provision_dhcp_server_for_bootcfg.yaml -i inventory.py >>./install.out 2>&1
fi

# Modifies the root user to include a shared SSH key for passwordless sudo during kubernetes cluster installation
if [ $? -eq 0 ]; then
  ansible-playbook add_user_for_kubernetes.yaml -i inventory.py >>./install.out 2>&1
fi

# Installs Docker and prerequisite packages, additionally modifies docker opts to include --dns=192.168.0.11
if [ $? -eq 0 ]; then
  ansible-playbook provision_docker_servers.yaml -i inventory.py >>./install.out 2>&1
fi

# Installs a Docker Registry and creates a SSL cert for Docker private registry usage
if [ $? -eq 0 ]; then
  ansible-playbook provision_docker_registry_servers.yaml -i inventory.py >>./install.out 2>&1
fi

# Copies new private registry's SSL cert to the kubernetes nodes
if [ $? -eq 0 ]; then
  ansible-playbook delegate_copy_ssl_cert.yaml -i inventory.py >>./install.out 2>&1
fi

# Downloads the kubernetes git repo and runs the cluster installation process to designated nodes
if [ $? -eq 0 ]; then
  ansible-playbook provision_kubernetes.yml -i inventory.py >>./install.out 2>&1
fi

# Runs the kubernetes cluster installation process to designated nodes
if [ $? -eq 0 ]; then
  ansible-playbook configure_and_run_kubernetes.yml -i inventory.py >>./install.out 2>&1
fi

# Deploys an nginx ingress controller and default backend in Kubernetes cluster
if [ $? -eq 0 ]; then
  ansible-playbook provision_kubernetes_ingress.yml -i inventory.py >>./install.out 2>&1
fi

# Builds a testing app to use in the new kubernetes cluster
#if [ $? -eq 0 ]; then
#  ansible-playbook docker_build_app.yml -i inventory.py >>./install.out 2>&1
#fi
#
## Deploys monitoring in Kubernetes cluster (InfluxDB, Grafana, Heapster)
#if [ $? -eq 0 ]; then
#  ansible-playbook provision_kubernetes_heapster.yml -i inventory.py >>./install.out 2>&1
#fi