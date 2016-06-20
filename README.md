CoreOS PXE Boot Environment
===================

Dependencies:
* Ansible >= 2.0
* Vagrant >= 1.8.1
* Virtualbox >= 5.0
* Virtualbox Extension Pack [https://www.virtualbox.org/wiki/Downloads](Download here) - Needed to enable PXE Booting to work correctly

You probably only need to have Ansible installed to get this environment up and running. Esp. if you are deploying to bare-metal or another hypervisor. You'll have to create a simple inventory file. Look at ansible/hosts.yaml or ansible/static_inventory to see what groups the playbooks use.

Create Environment with Vagrant
===============================

I use vagrant-hostsupdater plugin to write to my Macbook's /etc/hosts file for DNS resolution. This is so I can resolve hostnames in my browser. There is a playbook that installs DNS into the private network, as well as updates resolv.conf to utilize the newly created DNS server. You can skip these playbooks if your environment contains DNS resolution.
```
vagrant up
```

###The vagrant environment:
Here is a yaml representation of the dynamic inventory. The idea is to use a JSON API for inventory, so:

NOTE: ansible user's ssh private key file is using $HOME. Adjust accordingly.

cat ansible/hosts.yaml
```
---

core_servers:
  hosts: [ core1.lan ]
  vars:
    ansible_ssh_user: vagrant
    ansible_ssh_private_key_file: "~/.vagrant.d/insecure_private_key"
kubernetes_master_servers:
  hosts: [ kmaster1.lan ]
  vars:
    ansible_ssh_user: vagrant
    ansible_ssh_private_key_file: "~/.vagrant.d/insecure_private_key"
kubernetes_minion_servers:
  hosts: [ ]
  vars:
    ansible_ssh_user: vagrant
    ansible_ssh_private_key_file: "~/.vagrant.d/insecure_private_key"
docker_registry_servers:
  hosts: [ ]
  vars:
    ansible_ssh_user: vagrant
    ansible_ssh_private_key_file: "~/.vagrant.d/insecure_private_key"
kubernetes_servers:
  children: [ kubernetes_master_servers, kubernetes_minion_servers ]
docker_servers:
  children: [ kubernetes_master_servers, kubernetes_minion_servers, docker_registry_servers ]
bootcfg_servers:
  children: [ kubernetes_master_servers ]
all:
  children: [ core_servers, kubernetes_master_servers, kubernetes_minion_servers, docker_registry_servers, bootcfg_servers ]
_meta:
  hostvars:
    core1.lan:
      vagrant_ip: "192.168.0.10"
      vagrant_mem: "512"
    kmaster1.lan:
      vagrant_ip: "192.168.0.11"
      vagrant_mem: "4096"
    knode1.lan:
      vagrant_ip: "192.168.0.20"
    knode2.lan:
      vagrant_ip: "192.168.0.21"
    dreg1.lan:
      vagrant_ip: "192.168.0.30"
```

Using these playbooks. Currently focusing on the PXE aspect and the bootcfg ignition tool at the moment.

cat ansible/run_playbooks.sh
```
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
```

###Start the bootcfg server on core1.lan:
```
bootcfg -address 0.0.0.0:8080
```

Change the data and assets paths like so:
```
bootcfg -address 0.0.0.0:8080 -data-path /opt/coreos-baremetal/examples -assets-path /opt/coreos-baremetal/examples/assets
```

###Create the new server to be PXE booted:

In Virtualbox, create a new Linux host.
It needs:
* a private host adapter on eth0, Using the same private adapter as the dhcp, and tftp server (in my case, vboxnet52)
* Nat adapter on eth1
* Blank disc
* Boot order set to Network

Private Host adapter

![Private Host Adapter](https://raw.githubusercontent.com/chrisjalinsky/dhcp-pxe-coreos/master/install_images/virtualbox_private_net_adapter.png)

NAT adapter

![Private Host Adapter](https://raw.githubusercontent.com/chrisjalinsky/dhcp-pxe-coreos/master/install_images/virtualbox_nat_adapter.png)

Blank Disk

![Private Host Adapter](https://raw.githubusercontent.com/chrisjalinsky/dhcp-pxe-coreos/master/install_images/sata_disk.png)

Boot Order

![Private Host Adapter](https://raw.githubusercontent.com/chrisjalinsky/dhcp-pxe-coreos/master/install_images/boot_order.png)


###Core1.lan:

```
kubectl --kubeconfig=/var/lib/bootcfg/assets/tls/kubeconfig get nodes
kubectl --kubeconfig=/var/lib/bootcfg/assets/tls/kubeconfig cluster-info
kubectl --kubeconfig=/var/lib/bootcfg/assets/tls/kubeconfig create -f https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml
kubectl --kubeconfig=/var/lib/bootcfg/assets/tls/kubeconfig cluster-info
```
