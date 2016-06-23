CoreOS PXE Boot Environment
===================

The following environment PXE boots a kubernetes cluster onto bare metal servers. This is currently implemented with Virtualbox VMs, but should cover different server types. The use case is local Kubernetes cluster. Included is a custom Docker build web application that is exposed and load balanced on the local network. It will be pulling it's image from a private Docker Registry which will be built as well.

###Overview:
* Manually add 3 bare metal servers (or Virtualbox) to local network (192.168.0.0/24)
* PXE boot install CoreOS to disk (/dev/sda)
* Reboot and run Ignition to build Etcd, Flannel, Kubernetes, Docker to disk
* Provision a DHCP, DNS, TFTP, Docker Private Registry, and CoreOS bootcfg server
* Create a load balanced ingress point into the cluster
* Set up Horizontal autoscaling for a custom Docker image
* Authenticate and pull the image from a Docker private registry
* Load test the autoscaling feature

###Dependencies:
* Ansible >= 2.0
* Vagrant >= 1.8.1
* Virtualbox >= 5.0
* Virtualbox Extension Pack [https://www.virtualbox.org/wiki/Downloads](Download here) - Needed to enable Virtualbox PXE Booting to work correctly

You probably only need to have Ansible installed to get this environment up and running. Esp. if you are deploying to bare-metal or another hypervisor. You'll have to create a simple inventory file. Look at ansible/static_inventory to see what groups the playbooks use.

Create Environment with Vagrant
===============================

I use vagrant-hostsupdater plugin to write to my Macbook's /etc/hosts file for DNS resolution. This is so I can resolve hostnames in my browser. There is a playbook that installs DNS into the private network, as well as updates resolv.conf to utilize the newly created DNS server. You can skip these playbooks if your environment contains DNS resolution.
```
vagrant up
```

###The vagrant environment:
Here is a yaml representation of the dynamic inventory. The idea is to use a JSON API to retrieve dynamic inventory, it's currently static:

NOTE: ansible user's ssh private key file is using $HOME. Adjust accordingly. The PXE servers havent been added here.

cat ansible/hosts.yaml
```
---

core_servers:
  hosts: [ core1.lan ]
  vars:
    ansible_ssh_user: vagrant
    ansible_ssh_private_key_file: "~/.vagrant.d/insecure_private_key"
all:
  children: [ core_servers ]
_meta:
  hostvars:
    core1.lan:
      vagrant_ip: "192.168.0.10"

```

###Run the Ansible Playbooks:
```
ansible/run_playbooks.sh
```
###Ansible playbooks overview:

Installs DNS in the environment, and is not necessary if DNS already exists
```
ansible-playbook provision_core_servers.yaml -i inventory.py
```

Updates the cluster node's resolv.conf to point to the previous playbook's DNS server(s), this is not necessary if DNS resolution already exists
```
ansible-playbook update_resolv.yaml -i inventory.py
```

Install tftpd pxe server
```
ansible-playbook provision_tftpd_server_for_bootcfg.yaml -i inventory.py
```

Install bootcfg server for coreos baremetal bootcfg api boot server
```
ansible-playbook provision_bootcfg_server.yaml -i inventory.py
```

Install dhcp server. The dhcpd.conf file static IP mappings for the pxe booted servers.
```
ansible-playbook provision_dhcp_server_for_bootcfg.yaml -i inventory.py
```

Install Docker. This is a role for Ubuntu machines.
```
ansible-playbook provision_docker_servers.yaml -i inventory.py
```

Install private Docker Registry. This is a role for Ubuntu machines.
```
ansible-playbook provision_docker_registry_servers.yaml -i inventory.py
```

Build test application from Dockerfile.
```
ansible-playbook provision_docker_nginx.yaml -i inventory.py
```

###Bootcfg Upstart service (Only relevant for Upstart init)

```
/etc/init/bootcfg.conf
bootcfg status
```
Manually Start the bootcfg server on core1.lan:
```
bootcfg -address 0.0.0.0:8080
```

Change the data and assets paths like so:
```
bootcfg -address 0.0.0.0:8080 -data-path /opt/coreos-baremetal/examples -assets-path /opt/coreos-baremetal/examples/assets
```

###Create the new servers to be PXE booted:

In Virtualbox, create 3 new Linux hosts (in my environment they are named pxe, pxe2, pxe3).
Each needs:
* a private host adapter on eth0, Using the same private adapter as the dhcp, and tftp server (in my case, vboxnet52)
* Nat adapter on eth1
* Blank hard drive
* Boot order set to Network. Ideally a one time PXE boot would be ideal, then to hard drive

Update the isc-dhcp-server templates and coreos_baremetal templates/groups host specific config's selector to include the mac address:


Private Host adapter

![Private Host Adapter](https://raw.githubusercontent.com/chrisjalinsky/dhcp-pxe-coreos/master/install_images/virtualbox_private_net_adapter.png)

NAT adapter

![Private Host Adapter](https://raw.githubusercontent.com/chrisjalinsky/dhcp-pxe-coreos/master/install_images/virtualbox_nat_adapter.png)

Blank Disk

![Private Host Adapter](https://raw.githubusercontent.com/chrisjalinsky/dhcp-pxe-coreos/master/install_images/sata_disk.png)

Boot Order

![Private Host Adapter](https://raw.githubusercontent.com/chrisjalinsky/dhcp-pxe-coreos/master/install_images/boot_order.png)


###Core1.lan:

A play run in the CoreOS Baremetal role, execs scripts/gen-k8s-certs.sh which puts ca.pem, apiserver.pem, keys into the TFTPD assets/tls/ folder available during ignition scripts, cloud configs, etc.


###Kubernetes dashboard
see roles/coreos_baremetal/templates/k8s-master.yaml for svc and rc implementation. This is built in to the PXE boot, but if you need to manually add a dashboard, here's  how:

```
kubectl create -f https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml
```

###To access the Dashboard, you have to find the node port on the master:
```
kubectl --namespace="kube-system" describe svc/kubernetes-dashboard
```
###FIX Resolv
Due to DHCP providing DNS resolution, the NAT addressing messes with the resolution of the outside Docker Registry.
```
DNS Resolution:
vi /etc/systemd/resolved.conf

[Resolve]
DNS=192.168.0.10
#FallbackDNS=
Domains=lan
#LLMNR=yes
#DNSSEC=no

systemctl restart systemd-resolved.service
```

###Using Private Registry, you need to create a kubernetes secret to use to pull images:

Copy the Registry certs to the k8s cluster to handle the Docker insecure registry error:
```
mkdir -p /etc/docker/certs.d/core1.lan
sudo scp vagrant@core1.lan:/etc/ssl/core1.lan/core1.lan.pem /etc/docker/certs.d/core1.lan/ca.pem
sudo cp /etc/docker/certs.d/core1.lan/ca.pem /etc/ssl/certs/core1.lan.pem
update-ca-certificates
systemctl restart docker.service
systemctl status docker.service
docker login https://core1.lan
systemctl status docker.service
systemctl status docker.service | less
systemctl status docker.service
docker pull core1.lan/appweb:v1
```

This secret is a base64 encoded version of the ~/.docker/config.json file:
```
cat ~/.docker/config.json | base64
```
And create a Secret with the output:
```
---
apiVersion: v1
kind: Secret
metadata:
  name: dreg-secret
data:
  .dockerconfigjson: ewoJImF1dGhzIjogewoJCSJodHRwczovL2NvcmUxLmxhbiI6IHsKCQkJImF1dGgiOiAiZEdWemRIVnpaWEk2Y0dGemN3PT0iCgkJfQoJfQp9
type: kubernetes.io/dockerconfigjson
```

Kubernetes Ingress Example:
```
https://github.com/nginxinc/kubernetes-ingress.git

After running kubectl create commands:

curl --resolve cafe.example.com:443:192.168.0.152 https://cafe.example.com/coffee --insecure
curl --resolve cafe.example.com:443:192.168.0.152 https://cafe.example.com/tea --insecure
```

Now create the App, Service, Ingress and Controllers:
NOTE: This is using a private Docker Registry, so the first creation is for the image pull secret
```
kubectl create -f k8s_secrets/docker_registry_secret.yaml 
kubectl create -f k8s_rcs/appweb_rc.yaml 
kubectl create -f k8s_services/appweb_svc.yaml 
kubectl create -f k8s_secrets/appweb_secret.yaml
kubectl create -f k8s_ingresses/appweb_ingress.yaml
kubectl create -f k8s_rcs/appweb_ingress_rc.yaml 
```

Creating a Deployment and Service for Application:
Shorthand command that creates the service as well (--expose):
```
kubectl run appweb-deployment --image=core1.lan/appweb:v1 --requests=cpu=200m --expose --port=80
```
Long hand:
```
---

apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    run: appweb-deployment
  name: appweb-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      run: appweb-deployment
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        run: appweb-deployment
    spec:
      containers:
      - image: core1.lan/appweb:v1
        imagePullPolicy: IfNotPresent
        name: appweb-deployment
        ports:
        - containerPort: 80
          protocol: TCP
        resources:
          requests:
            cpu: 200m
      imagePullSecrets:
      - name: dreg-secret
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      securityContext: {}
      terminationGracePeriodSeconds: 30
```
Service to Expose on the Nodes:
```
---

apiVersion: v1
kind: Service
metadata:
  name: appweb-service
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    run: appweb-deployment
  type: LoadBalancer
```

Now Horizontally Autoscale the deployment:
```
kubectl autoscale deployment appweb-deployment --cpu-percent=50 --min=3 --max=10
```
Longhand:

```
---

apiVersion: extensions/v1beta1
kind: HorizontalPodAutoscaler
metadata:
  name: appweb-deployment
spec:
  cpuUtilization:
    targetPercentage: 50
  maxReplicas: 10
  minReplicas: 3
  scaleRef:
    apiVersion: extensions/v1beta1
    kind: Deployment
    name: appweb-deployment
    subresource: scale
```

To view Horizontal Pod Autoscale resource usage:
```
root@core1:/opt# kubectl get hpa
NAME                REFERENCE                            TARGET    CURRENT   MINPODS   MAXPODS   AGE
appweb-deployment   Deployment/appweb-deployment/scale   50%       0%        3         10        6m
```

Now, to reach this service from the outside, without looking up the NodePort, as well as load balance the exposed service:

Create an ingress for the service:
```
---

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: appweb-ingress
  namespace: default
spec:
  rules:
  - http:
      paths:
      - backend:
          serviceName: appweb-service
          servicePort: 80
        path: /ingress
```

Finally, we need a load balancer to dynamically poll and route between the available services endpoints:
```
---

apiVersion: v1
kind: ReplicationController
metadata:
  name: appweb-ingress-rc
  labels:
    app: appweb-ingress
spec:
  replicas: 1
  selector:
    app: appweb-ingress
  template:
    metadata:
      labels:
        app: appweb-ingress
    spec:
      containers:
      - image: nginxdemos/nginx-ingress:0.3
        imagePullPolicy: Always
        name: appweb-ingress
        ports:
        - containerPort: 80
          hostPort: 80
```
###Additional Horizontal Pod Autoscaling details:

Heapster Autoscale algorithm (https://github.com/kubernetes/kubernetes/blob/release-1.2/docs/design/horizontal-pod-autoscaler.md)[described here]:
```
TargetNumOfPods = ceil(sum(CurrentPodsCPUUtilization) / Target)
```

The heapster pod exposes an internal cluster endpoint, curl the metrics to see Heapster metrics:
In my case, ```10.20.88.2:8082``` is the exposed internal heapster service:

###Curl from inside the cluster:
```
curl http://10.20.88.2:8082/metrics
curl http://10.20.88.2:8082/api/v1/model/debug/allkeys
```

###Heapster logs:

```
kubectl --namespace=kube-system get po
```

Several logs to watch, heapster and heapster-nanny:
```
kubectl --namespace=kube-system logs heapster-v1.0.2-808903792-eod7e heapster
kubectl --namespace=kube-system logs heapster-v1.0.2-808903792-eod7e heapster-nanny
```

Additional Curl requests to specific pods:
============

```
curl http://172.16.102.6:8082/api/v1/model/namespaces/default/pods//hello-world-819237062-j0ubt/metrics/cpu-usage
```

###Siege

Once you've gotten this far, let's run a load test against the ingress point to test autoscaling:

On core1.lan, run siege. You'll need to locate the ingress point first before making siege requests. To do this, find which node the ingress controller has been assigned to. You can find that in the dashboard.
```
apt-get install siege
siege -c 20 http://<node with ingress rc>/ingress
```


Kubernetes quick command to create and expose on NodePort:
```
kubectl run my-nginx --image=core1.lan/appweb:v1 --replicas=2 --port=80 --expose --service-overrides='{ "spec": { "type": "NodePort" } }'
```
