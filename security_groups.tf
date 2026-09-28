resource "openstack_networking_secgroup_v2" "cluster" {
  name                 = "${var.cluster_name}-cluster"
  description          = "Private east-west traffic between Kubernetes nodes"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_rule_v2" "cluster_internal_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.cluster.id
  security_group_id = openstack_networking_secgroup_v2.cluster.id
}

resource "openstack_networking_secgroup_rule_v2" "cluster_egress_ipv4" {
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.cluster.id
}

resource "openstack_networking_secgroup_v2" "control_plane" {
  name                 = "${var.cluster_name}-control-plane"
  description          = "Ingress rules for Kubernetes control-plane nodes"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_rule_v2" "api_from_node_subnet" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = local.effective_node_subnet_cidr
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "api_from_allowed_cidrs" {
  for_each = var.api_allowed_cidrs

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = each.value
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "ssh_from_allowed_cidrs" {
  for_each = var.ssh_allowed_cidrs

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.value
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_v2" "worker" {
  name                 = "${var.cluster_name}-worker"
  description          = "Role marker for Kubernetes worker nodes; east-west rules are in the cluster group"
  delete_default_rules = true
}
