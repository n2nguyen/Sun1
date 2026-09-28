resource "openstack_lb_loadbalancer_v2" "kube_api" {
  count = var.create_api_load_balancer ? 1 : 0

  name                  = "${var.cluster_name}-api"
  vip_subnet_id         = local.subnet_id
  flavor_id             = var.api_load_balancer_flavor_id
  availability_zone     = var.api_load_balancer_availability_zone
  loadbalancer_provider = var.api_load_balancer_provider
}

resource "openstack_lb_listener_v2" "kube_api" {
  count = var.create_api_load_balancer ? 1 : 0

  name                   = "${var.cluster_name}-api-6443"
  protocol               = "TCP"
  protocol_port          = 6443
  loadbalancer_id        = openstack_lb_loadbalancer_v2.kube_api[0].id
  timeout_client_data    = var.api_listener_idle_timeout_ms
  timeout_member_data    = var.api_listener_idle_timeout_ms
  timeout_member_connect = var.api_listener_connect_timeout_ms
  allowed_cidrs = sort(tolist(setunion(
    var.api_allowed_cidrs,
    toset([local.effective_node_subnet_cidr]),
  )))
}

resource "openstack_lb_pool_v2" "kube_api" {
  count = var.create_api_load_balancer ? 1 : 0

  name        = "${var.cluster_name}-api"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.kube_api[0].id
}

resource "openstack_lb_member_v2" "control_plane" {
  for_each = var.create_api_load_balancer ? local.control_plane_nodes : {}

  name          = each.value.name
  pool_id       = openstack_lb_pool_v2.kube_api[0].id
  subnet_id     = local.subnet_id
  address       = openstack_networking_port_v2.control_plane[each.key].all_fixed_ips[0]
  protocol_port = 6443

  depends_on = [openstack_compute_instance_v2.control_plane]
}

resource "openstack_lb_monitor_v2" "kube_api" {
  count = var.create_api_load_balancer ? 1 : 0

  name        = "${var.cluster_name}-api"
  pool_id     = openstack_lb_pool_v2.kube_api[0].id
  type        = "TCP"
  delay       = 5
  timeout     = 3
  max_retries = 3
}

resource "openstack_networking_floatingip_v2" "kube_api" {
  count = var.create_api_load_balancer && var.create_api_floating_ip ? 1 : 0
  pool  = coalesce(var.external_network_name, "__external_network_name_is_required__")

  lifecycle {
    precondition {
      condition     = length(var.api_allowed_cidrs) > 0
      error_message = "api_allowed_cidrs must not be empty when create_api_floating_ip is true."
    }
  }
}

resource "openstack_networking_floatingip_associate_v2" "kube_api" {
  count       = var.create_api_load_balancer && var.create_api_floating_ip ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.kube_api[0].address
  port_id     = openstack_lb_loadbalancer_v2.kube_api[0].vip_port_id

  depends_on = [openstack_networking_router_interface_v2.cluster]
}

resource "openstack_networking_floatingip_v2" "bootstrap" {
  count = var.create_bootstrap_floating_ip ? 1 : 0
  pool  = coalesce(var.external_network_name, "__external_network_name_is_required__")

  lifecycle {
    precondition {
      condition     = length(var.ssh_allowed_cidrs) > 0
      error_message = "ssh_allowed_cidrs must not be empty when create_bootstrap_floating_ip is true."
    }
  }
}

resource "openstack_networking_floatingip_associate_v2" "bootstrap" {
  count       = var.create_bootstrap_floating_ip ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.bootstrap[0].address
  port_id     = openstack_networking_port_v2.control_plane[local.first_control_plane_key].id

  depends_on = [openstack_networking_router_interface_v2.cluster]
}
