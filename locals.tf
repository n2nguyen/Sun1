locals {
  control_plane_nodes = {
    for index in range(var.control_plane_count) : format("cp-%02d", index + 1) => {
      name = format("%s-cp-%02d", var.cluster_name, index + 1)
      az   = element(var.availability_zones, index)
    }
  }

  worker_nodes = {
    for index in range(var.worker_count) : format("worker-%02d", index + 1) => {
      name             = format("%s-worker-%02d", var.cluster_name, index + 1)
      az               = element(var.availability_zones, index)
      server_group_key = format("group-%02d", floor(index / var.worker_server_group_size) + 1)
    }
  }

  worker_server_groups = {
    for index in range(ceil(var.worker_count / var.worker_server_group_size)) :
    format("group-%02d", index + 1) => format("%s-worker-%02d", var.cluster_name, index + 1)
  }

  first_control_plane_key = sort(keys(local.control_plane_nodes))[0]

  node_image_id = var.image_id != null ? var.image_id : data.openstack_images_image_v2.node[0].id

  network_id = var.create_network ? openstack_networking_network_v2.cluster[0].id : data.openstack_networking_network_v2.existing[0].id
  subnet_id  = var.create_network ? openstack_networking_subnet_v2.cluster[0].id : data.openstack_networking_subnet_v2.existing[0].id

  effective_node_subnet_cidr = var.create_network ? var.node_subnet_cidr : data.openstack_networking_subnet_v2.existing[0].cidr

  need_external_network = var.create_network || var.create_api_floating_ip || var.create_bootstrap_floating_ip

  kubernetes_api_ip_address = var.create_api_load_balancer ? (
    var.create_api_floating_ip ? openstack_networking_floatingip_v2.kube_api[0].address : openstack_lb_loadbalancer_v2.kube_api[0].vip_address
  ) : openstack_networking_port_v2.control_plane[local.first_control_plane_key].all_fixed_ips[0]

  kubernetes_api_address = coalesce(var.api_dns_name, local.kubernetes_api_ip_address)
}
