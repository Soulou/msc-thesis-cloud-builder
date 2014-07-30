Cloud Builder
================

Project built for an assignment for the Cloud Computing module of the Msc in
Computer and Softwares Techniques in Engineering, Option Distributed Computing
and e-science. Then upgraded in the scope of the Msc Thesis to deploy a container
cloud and executing load balancing experiments.

Usage
-----

### Deployment scripts

```
# Create the cloud
./create_cluster.rb <n>

# Destroy it and its network
./create_cluster.rb --purge

# Rewrite ansible hosts file according to existing cloud
./create_cluster.rb --ansible

Configuration from environment
------------------------------

These are the default values, any of them is overridable through the environment

```
NETWORK_NAME = "s202926-net"
SUBNET_NAME  = "s202926-subnet"
SUBNET_RANGE = "192.168.111.0/24"
DNS_NAMESERVER = "10.7.0.3"
ROUTER_NAME = "s202926-router"
PUB_KEY_FILE= "#{ENV["HOME"]}/.ssh/id_rsa.pub"
KEYPAIR_NAME = "s202926-key"
INSTANCE_PREFIX = "s202926vm-"
INSTANCE_FLAVOR = 2
VM_IMAGE = "ubuntu-precise"
MAX_WAIT_TIME = 180
```

