variable environment {
    type =  object({
                    prefix = string, 
                    master_nodes = string, 
                    master_az = string,
                    worker_nodes = string, 
                    worker_az = string,
                     nfs_nodes = string,
                     nfs_az = string,
                     registry_nodes = string,
                     registry_az = string,
                     public_key = string, 
                     image = string, 
                     lb_network = string,
                     lb_subnet = string,
                     internal_subnet_cidr = string,
                     external_network = string,
                     internal_subnet_gw = string,
                     dns_nameservers = list(string),
                     external_subnet = string,
                     nfs_flavor = string,
                     bastian_flavor = string,
                     bastian_az = string,
                     registry_flavor = string,
                     domain = string,
                     master_flavor = string,
                     worker_flavor = string                   
                     })
    default = {
        prefix = "k8s"
        master_nodes = "1",
        master_az = "zone2",
        worker_nodes = "6",
        worker_az = "zone2",
        registry_nodes = "0",
        registry_az = "zone1",
        nfs_nodes =  "1",
        nfs_az = "zone1",
        image = "debian_11",
        bastian_flavor = "m1.medium",
        bastian_az = "zone1",
        master_flavor = "m1.xlarge",
        worker_flavor = "m2.xlarge",
        nfs_flavor = "m1.medium",
        registry_flavor = "m1.medium",
        public_key = "ssh_keys/id_rsa.pub",
        private_key = "ssh_keys/id_rsa",
        internal_subnet_cidr = "10.20.0.0/24",
        internal_subnet_gw = "10.20.0.1",
        dns_nameservers = [ "10.2.1.55" ],
        domain = "kube.int.",
        external_network = "lb",
        external_subnet = "lb",
        lb_network = "lb",
        lb_subnet = "lb"    
    }
}

variable "create_block_device" {
  type    = bool
  default = true
}
