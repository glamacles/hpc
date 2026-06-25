# Keypair, security group, and the private network/subnet/router.

resource "openstack_compute_keypair_v2" "admin" {
  name       = var.keypair_name
  public_key = file(pathexpand(var.admin_pubkey))
}

resource "openstack_networking_secgroup_v2" "sg" {
  name        = var.secgroup
  description = "GLAMacles: ssh + jupyterhub"
}

# 22 (ssh), 80 + 443 (JupyterHub). Open to the world; tighten remote_ip_prefix
# to campus ranges if you can.
resource "openstack_networking_secgroup_rule_v2" "ingress" {
  for_each          = toset(["22", "80", "443"])
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = tonumber(each.value)
  port_range_max    = tonumber(each.value)
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg.id
}

data "openstack_networking_network_v2" "public" {
  name = var.public_network
}

resource "openstack_networking_network_v2" "net" {
  name = var.network
}

resource "openstack_networking_subnet_v2" "subnet" {
  name            = var.subnet
  network_id      = openstack_networking_network_v2.net.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "1.1.1.1"]
}

resource "openstack_networking_router_v2" "router" {
  name                = var.router
  external_network_id = data.openstack_networking_network_v2.public.id
}

resource "openstack_networking_router_interface_v2" "ri" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}
