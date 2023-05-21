terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "1.47.0"
    }
  }
}

resource "openstack_networking_network_v2" "network" {
  name = "${var.environment.prefix}_int_net"
}

resource "openstack_networking_subnet_v2" "subnet" {
  name            = "${var.environment.prefix}_int_sub"
  network_id      = openstack_networking_network_v2.network.id
  cidr            = var.environment.internal_subnet_cidr
  gateway_ip      = var.environment.internal_subnet_gw
  dns_nameservers = var.environment.dns_nameservers

}

resource "openstack_compute_keypair_v2" "keypair" {
  name          = "${var.environment.prefix}"
  public_key    = file(var.environment.public_key)
}

data "openstack_networking_network_v2" "ext_net"{
  name = var.environment.external_network
}

data "openstack_networking_subnet_v2" "ext_sub_net"{
  name = var.environment.external_subnet
}

data "openstack_networking_network_v2" "lb_net"{
  name = var.environment.lb_network
}

data "openstack_networking_subnet_v2" "lb_subnet"{
  name = var.environment.lb_subnet
}

data openstack_images_image_v2 image_01 {
  name = var.environment.image
}


# Router
resource "openstack_networking_router_v2" "router" {
  name                = "${var.environment.prefix}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.ext_net.id
  depends_on = [
      openstack_networking_subnet_v2.subnet,
      openstack_networking_network_v2.network,
  ]
}

resource "openstack_networking_router_interface_v2" "router_interface_01" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet.id

  depends_on = [
      openstack_networking_subnet_v2.subnet,
      openstack_networking_network_v2.network,
      openstack_networking_router_v2.router
  ]
}


resource "openstack_networking_secgroup_v2" "k8s_secgroup" {
  name        = "k8s_secgroup"
  description = "Security group for k8s"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.k8s_secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 22
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.k8s_secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_udp_out" {
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 22
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.k8s_secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_sctp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "sctp"
  port_range_min    = "38412"
  port_range_max    = "38412"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.k8s_secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_sctp2" {
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "sctp"
  port_range_min    = "38412"
  port_range_max    = "38412"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.k8s_secgroup.id}"
}

# Security group (for now, everything is open)
/*
resource "openstack_compute_secgroup_v2" "secgroup" {
  name        = "${var.environment.prefix}-secgroup"
  description = "secgroup"
  
  rule {
    from_port   = 22
    to_port     = 65535
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"    
  }

  rule {
    from_port   = 22
    to_port     = 65535
    ip_protocol = "udp"
    cidr        = "0.0.0.0/0"    
  }  

  
  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
    #cidr        = var.environment.internal_subnet_cidr
  }  
}

*/
#########################################################################################################
#     Bastian node
#########################################################################################################
resource "openstack_compute_instance_v2" "bastian" {
  name            = "${var.environment.prefix}-bastian"
  flavor_name     = var.environment.bastian_flavor
  image_name      = var.environment.image
  key_pair        = openstack_compute_keypair_v2.keypair.name
  availability_zone = var.environment.bastian_az
  security_groups = [ openstack_networking_secgroup_v2.k8s_secgroup.name ]
  network {
    name = openstack_networking_network_v2.network.name
  }

  depends_on = [
    openstack_networking_network_v2.network,
    openstack_networking_subnet_v2.subnet,
    openstack_networking_router_interface_v2.router_interface_01
  ]
}

# Create a list of floating IPs
resource "openstack_networking_floatingip_v2" "bastian_floating_ip" {
  pool  = var.environment.external_network
  subnet_id = data.openstack_networking_subnet_v2.ext_sub_net.id
}

# Associate floating IPs with instances
resource "openstack_compute_floatingip_associate_v2" "bastian_floating_ip_associate" {
  floating_ip     = openstack_networking_floatingip_v2.bastian_floating_ip.address
  fixed_ip        = openstack_compute_instance_v2.bastian.network.0.fixed_ip_v4
  instance_id     = openstack_compute_instance_v2.bastian.id
  depends_on      = [openstack_compute_instance_v2.bastian, openstack_networking_floatingip_v2.bastian_floating_ip]
}


#########################################################################################################
#     Master nodes
#########################################################################################################
resource "openstack_compute_instance_v2" "master" {
  count           = var.environment.master_nodes
  name            = "${var.environment.prefix}-master-${count.index}"
  flavor_name     = var.environment.master_flavor
  image_name      = var.environment.image
  key_pair        = openstack_compute_keypair_v2.keypair.name
  availability_zone = var.environment.master_az
  security_groups = [ openstack_networking_secgroup_v2.k8s_secgroup.name  ]
  network {
    name = openstack_networking_network_v2.network.name
  }

  depends_on = [
    openstack_networking_network_v2.network,
    openstack_networking_subnet_v2.subnet,
    openstack_networking_router_interface_v2.router_interface_01
  ]
}

# Create a list of floating IPs
resource "openstack_networking_floatingip_v2" "master_floating_ip" {
  count = var.environment.master_nodes
  pool  = var.environment.external_network
  subnet_id = data.openstack_networking_subnet_v2.ext_sub_net.id
}

# Associate floating IPs with instances
resource "openstack_compute_floatingip_associate_v2" "master_floating_ip_associate" {
  count           = var.environment.master_nodes
  floating_ip     = openstack_networking_floatingip_v2.master_floating_ip[count.index].address
  fixed_ip        = openstack_compute_instance_v2.master[count.index].network.0.fixed_ip_v4
  instance_id     = openstack_compute_instance_v2.master[count.index].id
  depends_on      = [openstack_compute_instance_v2.master, openstack_networking_floatingip_v2.master_floating_ip]
}

#########################################################################################################
# Worker nodes
#########################################################################################################
resource "openstack_compute_instance_v2" "worker" {
  count           = var.environment.worker_nodes
  name            = "${var.environment.prefix}-worker-${count.index}"
  flavor_name     = var.environment.worker_flavor
  image_name      = var.environment.image
  key_pair        = openstack_compute_keypair_v2.keypair.name
  availability_zone = var.environment.worker_az
  security_groups = [ openstack_networking_secgroup_v2.k8s_secgroup.name ]
  network {
    name = openstack_networking_network_v2.network.name
  }

  depends_on = [
    openstack_networking_network_v2.network,
    openstack_networking_subnet_v2.subnet,
    openstack_networking_router_interface_v2.router_interface_01
  ]
}

# Create a list of floating IPs
resource "openstack_networking_floatingip_v2" "worker_floating_ip" {
  count = var.environment.worker_nodes
  pool  = var.environment.external_network
  subnet_id = data.openstack_networking_subnet_v2.ext_sub_net.id
}

# Associate floating IPs with instances
resource "openstack_compute_floatingip_associate_v2" "worker_floating_ip_associate" {
  count           = var.environment.worker_nodes
  floating_ip     = openstack_networking_floatingip_v2.worker_floating_ip[count.index].address
  fixed_ip        = openstack_compute_instance_v2.worker[count.index].network.0.fixed_ip_v4
  instance_id     = openstack_compute_instance_v2.worker[count.index].id
  depends_on      = [openstack_compute_instance_v2.worker, openstack_networking_floatingip_v2.worker_floating_ip]
}


#########################################################################################################
# Registry nodes
#########################################################################################################

resource "openstack_compute_instance_v2" "registry" {
  count           = var.environment.registry_nodes
  name            = "${var.environment.prefix}-registry-${count.index}"
  flavor_name     = var.environment.registry_flavor
  image_name      = var.environment.image
  key_pair        = openstack_compute_keypair_v2.keypair.name
  availability_zone = var.environment.registry_az
  security_groups = [ openstack_networking_secgroup_v2.k8s_secgroup.name  ]
  network {
    name = openstack_networking_network_v2.network.name
  }

  /*
  block_device {
    uuid                  = data.openstack_images_image_v2.image_01.id
    source_type           = "image"
    volume_size           = 80
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  } */

  depends_on = [
    openstack_networking_network_v2.network,
    openstack_networking_subnet_v2.subnet,
    openstack_networking_router_interface_v2.router_interface_01
  ]
}

# Create a list of floating IPs
resource "openstack_networking_floatingip_v2" "registry_floating_ip" {
  count = var.environment.registry_nodes
  pool  = var.environment.external_network
  subnet_id = data.openstack_networking_subnet_v2.ext_sub_net.id
}

# Associate floating IPs with instances
resource "openstack_compute_floatingip_associate_v2" "registry_floating_ip_associate" {
  count           = var.environment.registry_nodes
  floating_ip     = openstack_networking_floatingip_v2.registry_floating_ip[count.index].address
  fixed_ip        = openstack_compute_instance_v2.registry[count.index].network.0.fixed_ip_v4
  instance_id     = openstack_compute_instance_v2.registry[count.index].id
  depends_on      = [openstack_compute_instance_v2.registry, openstack_networking_floatingip_v2.registry_floating_ip]
}

#########################################################################################################
# NFS nodes
#########################################################################################################

resource "openstack_compute_instance_v2" "nfs" {
  count           = var.environment.nfs_nodes
  name            = "${var.environment.prefix}-nfs-${count.index}"
  flavor_name     = var.environment.nfs_flavor
  image_name      = var.environment.image
  availability_zone = var.environment.nfs_az
  security_groups = [ openstack_networking_secgroup_v2.k8s_secgroup.name  ]
  key_pair        = openstack_compute_keypair_v2.keypair.name
  network {
    name = openstack_networking_network_v2.network.name
  }
  
  /*
  block_device {
    uuid                  = data.openstack_images_image_v2.image_01.id
    source_type           = "image"
    volume_size           = 80
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
  */

  depends_on = [
    openstack_networking_network_v2.network,
    openstack_networking_subnet_v2.subnet,
    openstack_networking_router_interface_v2.router_interface_01
  ]
}

# Create a list of floating IPs
resource "openstack_networking_floatingip_v2" "nfs_floating_ip" {
  count = var.environment.nfs_nodes
  pool  = var.environment.external_network
  subnet_id = data.openstack_networking_subnet_v2.ext_sub_net.id
}

# Associate floating IPs with instances
resource "openstack_compute_floatingip_associate_v2" "nfs_floating_ip_associate" {
  count           = var.environment.nfs_nodes
  floating_ip     = openstack_networking_floatingip_v2.nfs_floating_ip[count.index].address
  fixed_ip        = openstack_compute_instance_v2.nfs[count.index].network.0.fixed_ip_v4
  instance_id     = openstack_compute_instance_v2.nfs[count.index].id
  depends_on      = [openstack_compute_instance_v2.nfs, openstack_networking_floatingip_v2.nfs_floating_ip]
}

#########################################################################################################
# Loadbalancer:
#########################################################################################################

resource "openstack_lb_loadbalancer_v2" "lb" {
  name          = "${var.environment.prefix}-lb"
  vip_subnet_id = openstack_networking_subnet_v2.subnet.id
  depends_on = [
    openstack_networking_subnet_v2.subnet
  ]
}

resource "openstack_lb_listener_v2" "listener" {
  name          = "${var.environment.prefix}-listener"
  protocol        = "TCP"
  protocol_port   = 6443
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb.id
  depends_on = [ 
    openstack_lb_loadbalancer_v2.lb
  ]
}

resource "openstack_lb_pool_v2" "pool" {
  name          = "${var.environment.prefix}-pool"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.listener.id
}

resource "openstack_lb_member_v2" "member" {
  count      = var.environment.master_nodes
  name       = element(openstack_compute_instance_v2.master.*.name, count.index)
  pool_id    = openstack_lb_pool_v2.pool.id
  address    = element(openstack_compute_instance_v2.master.*.access_ip_v4, count.index)
  protocol_port = 6443
  depends_on = [
    openstack_lb_pool_v2.pool,
    openstack_compute_instance_v2.master,
  ]
}

# Loadbalancer floating ip
resource "openstack_networking_floatingip_v2" "lb_floating_ip" {
  pool  = var.environment.lb_network
  subnet_id = data.openstack_networking_subnet_v2.lb_subnet.id
}

# Associate floating IPs with lb
resource "openstack_networking_floatingip_associate_v2" "lb_floating_ip_associate" {
  floating_ip = openstack_networking_floatingip_v2.lb_floating_ip.address
  port_id     = openstack_lb_loadbalancer_v2.lb.vip_port_id
  depends_on = [
    openstack_networking_floatingip_v2.lb_floating_ip,
    openstack_lb_loadbalancer_v2.lb
  ]
}

#########################################################################################################
# Domain and recordsets
#########################################################################################################
resource "openstack_dns_zone_v2" "zone" {
  name        = var.environment.domain
  email       = "foo@foo.com"
  description = "An example zone"
  ttl         = 3000
  type        = "PRIMARY"
}


# Loadbalancer
resource "openstack_dns_recordset_v2" "api" {
  zone_id     = openstack_dns_zone_v2.zone.id
  name        = "api.${var.environment.domain}"
  description = " K8s api"
  ttl         = 3000
  type        = "A"
  records     = [ openstack_networking_floatingip_v2.lb_floating_ip.address ]
}

# Bastian
resource "openstack_dns_recordset_v2" "bastian" {
  zone_id     = openstack_dns_zone_v2.zone.id
  name        = "${openstack_compute_instance_v2.bastian.name}.${var.environment.domain}"
  description = "Recordset k8s"
  ttl         = 3000
  type        = "A"
  #records     = [ openstack_compute_instance_v2.bastian.access_ip_v4 ]
  records     = [ openstack_networking_floatingip_v2.bastian_floating_ip.address ]
}


# Master
resource "openstack_dns_recordset_v2" "master" {
  count      = var.environment.master_nodes
  zone_id     = openstack_dns_zone_v2.zone.id
  name        = "${element(openstack_compute_instance_v2.master.*.name, count.index)}.${var.environment.domain}"
  description = "Recordset k8s"
  ttl         = 3000
  type        = "A"
  records     = [ element(openstack_compute_instance_v2.master.*.access_ip_v4, count.index) ]
}

# Worker
resource "openstack_dns_recordset_v2" "worker" {
  count      = var.environment.worker_nodes
  zone_id     = openstack_dns_zone_v2.zone.id
  name        = "${element(openstack_compute_instance_v2.worker.*.name, count.index)}.${var.environment.domain}"
  description = "Recordset k8s"
  ttl         = 3000
  type        = "A"
  records     = [ element(openstack_compute_instance_v2.worker.*.access_ip_v4, count.index) ]
}


# NFS
resource "openstack_dns_recordset_v2" "nfs" {
  count      = var.environment.nfs_nodes
  zone_id     = openstack_dns_zone_v2.zone.id
  name        = "${element(openstack_compute_instance_v2.nfs.*.name, count.index)}.${var.environment.domain}"
  description = "Recordset k8s"
  ttl         = 3000
  type        = "A"
  records     = [ element(openstack_compute_instance_v2.nfs.*.access_ip_v4, count.index) ]
}

resource "openstack_dns_recordset_v2" "nfs_vip" {
  zone_id     = openstack_dns_zone_v2.zone.id
  name        = "nfs.${var.environment.domain}"
  description = "Recordset k8s"
  ttl         = 3000
  type        = "A"
  records     = [for instance in openstack_compute_instance_v2.nfs : instance.access_ip_v4]
}

# REGISTRY
resource "openstack_dns_recordset_v2" "registry" {
  count      = var.environment.registry_nodes
  zone_id     = openstack_dns_zone_v2.zone.id
  name        = "${element(openstack_compute_instance_v2.registry.*.name, count.index)}.${var.environment.domain}"
  description = "Recordset k8s"
  ttl         = 3000
  type        = "A"
  records     = [ element(openstack_compute_instance_v2.registry.*.access_ip_v4, count.index) ]
  #records     = [ element(openstack_networking_floatingip_v2.registry_floating_ip.*.address, count.index) ] 
}

resource "openstack_dns_recordset_v2" "registry_vip" {
  zone_id     = openstack_dns_zone_v2.zone.id
  name        = "registry.${var.environment.domain}"
  description = "Recordset k8s"
  ttl         = 3000
  type        = "A"
  records     = [for instance in openstack_networking_floatingip_v2.registry_floating_ip : instance.address]
}


#########################################################################################################
# Output:
#########################################################################################################

resource "local_file" "bastian" {
  filename = "bastian.txt"
  content  = "${openstack_compute_instance_v2.bastian.id} ${openstack_compute_instance_v2.bastian.name} ${openstack_compute_instance_v2.bastian.access_ip_v4}"
}

resource "local_file" "master" {
  filename = "master.txt"
  content  = join("\n", [for instance in openstack_compute_instance_v2.master : "${instance.id} ${instance.name} ${instance.access_ip_v4}"])
}

resource "local_file" "worker" {
  filename = "worker.txt"
  content  = join("\n", [for instance in openstack_compute_instance_v2.worker : "${instance.id} ${instance.name} ${instance.access_ip_v4}"])
}

resource "local_file" "nfs" {
  filename = "nfs.txt"
  content  = join("\n", [for instance in openstack_compute_instance_v2.nfs : "${instance.id} ${instance.name} ${instance.access_ip_v4}"])
}

resource "local_file" "registry" {
  filename = "registry.txt"
  content  = join("\n", [for instance in openstack_compute_instance_v2.registry : "${instance.id} ${instance.name} ${instance.access_ip_v4}"])
}

resource "local_file" "domain"{
  filename = "domain.txt"
  content = "${var.environment.domain}"
}

resource "local_file" "int_network"{
  filename = "int_network.txt"
  content = "${var.environment.internal_subnet_cidr}"
}

resource "local_file" "dns" {
  filename = "dns.txt"
  content  = join("\n", [for dns in var.environment.dns_nameservers : "${dns}"])
}

resource "local_file" "lb_vip_address" {
  content  = "${openstack_lb_loadbalancer_v2.lb.vip_address}"
  filename = "lb_vip_address.txt"
}

resource "local_file" "floating_network_id" {
  content  = "${data.openstack_networking_network_v2.lb_net.id}"
  filename = "floating_network_id.txt"
}

resource "local_file" "internal_subnet_id" {
  content  = "${openstack_networking_subnet_v2.subnet.id}"
  filename = "internal_subnet_id.txt"
}
