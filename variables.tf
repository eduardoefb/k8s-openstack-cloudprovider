variable environment {
    type =  object({
                    prefix = string, 
                    master_nodes = string, 
                     worker_nodes = string, 
                     nfs_nodes = string,
                     registry_nodes = string,
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
                     registry_flavor = string,
                     domain = string,
                     master_flavor = string,
                     worker_flavor = string})
    default = {
        prefix = "k8s"
        master_nodes = "3",
        worker_nodes = "3",
        registry_nodes = "1",
        nfs_nodes =  "1",
        image = "debian_11",
        bastian_flavor = "m1.medium",
        master_flavor = "m1.xlarge",
        worker_flavor = "m1.xlarge",
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
