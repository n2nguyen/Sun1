resource "openstack_networking_network_v2" "cluster" {
  count          = var.create_network ? 1 : 0
  name           = var.network_name
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "cluster" {
  count           = var.create_network ? 1 : 0
  name            = var.subnet_name
  network_id      = openstack_networking_network_v2.cluster[0].id
  cidr            = var.node_subnet_cidr
  ip_version      = 4
  enable_dhcp     = true
  gateway_ip      = cidrhost(var.node_subnet_cidr, 1)
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_router_v2" "cluster" {
  count               = var.create_network ? 1 : 0
  name                = var.router_name
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external[0].id
}

resource "openstack_networking_router_interface_v2" "cluster" {
  count     = var.create_network ? 1 : 0
  router_id = openstack_networking_router_v2.cluster[0].id
  subnet_id = openstack_networking_subnet_v2.cluster[0].id
}

resource "openstack_networking_port_v2" "control_plane" {
  for_each = local.control_plane_nodes

  name                  = "${each.value.name}-port"
  network_id            = local.network_id
  admin_state_up        = true
  port_security_enabled = true
  security_group_ids = [
    openstack_networking_secgroup_v2.cluster.id,
    openstack_networking_secgroup_v2.control_plane.id,
  ]

  fixed_ip {
    subnet_id = local.subnet_id
  }
}

resource "openstack_networking_port_v2" "worker" {
  for_each = local.worker_nodes

  name                  = "${each.value.name}-port"
  network_id            = local.network_id
  admin_state_up        = true
  port_security_enabled = true
  security_group_ids = [
    openstack_networking_secgroup_v2.cluster.id,
    openstack_networking_secgroup_v2.worker.id,
  ]

  fixed_ip {
    subnet_id = local.subnet_id
  }
}

