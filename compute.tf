resource "openstack_compute_instance_v2" "control_plane" {
  for_each = local.control_plane_nodes

  name              = each.value.name
  availability_zone = each.value.az
  flavor_id         = data.openstack_compute_flavor_v2.control_plane.id
  image_id          = var.boot_from_volume ? null : local.node_image_id
  key_pair          = var.keypair_name
  config_drive      = true

  metadata = merge(var.resource_tags, {
    cluster = var.cluster_name
    role    = "control-plane"
  })

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    hostname              = each.value.name
    role                  = "control-plane"
    timezone              = var.timezone
    prepare_kubernetes_os = var.prepare_kubernetes_os
  })

  dynamic "block_device" {
    for_each = var.boot_from_volume ? [1] : []

    content {
      uuid                  = local.node_image_id
      source_type           = "image"
      destination_type      = "volume"
      volume_size           = var.control_plane_root_volume_size
      boot_index            = 0
      delete_on_termination = true
    }
  }

  network {
    port = openstack_networking_port_v2.control_plane[each.key].id
  }

  scheduler_hints {
    group = openstack_compute_servergroup_v2.control_plane.id
  }

  depends_on = [openstack_networking_router_interface_v2.cluster]
}

resource "openstack_compute_instance_v2" "worker" {
  for_each = local.worker_nodes

  name              = each.value.name
  availability_zone = each.value.az
  flavor_id         = data.openstack_compute_flavor_v2.worker.id
  image_id          = var.boot_from_volume ? null : local.node_image_id
  key_pair          = var.keypair_name
  config_drive      = true

  metadata = merge(var.resource_tags, {
    cluster = var.cluster_name
    role    = "worker"
  })

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    hostname              = each.value.name
    role                  = "worker"
    timezone              = var.timezone
    prepare_kubernetes_os = var.prepare_kubernetes_os
  })

  dynamic "block_device" {
    for_each = var.boot_from_volume ? [1] : []

    content {
      uuid                  = local.node_image_id
      source_type           = "image"
      destination_type      = "volume"
      volume_size           = var.worker_root_volume_size
      boot_index            = 0
      delete_on_termination = true
    }
  }

  network {
    port = openstack_networking_port_v2.worker[each.key].id
  }

  scheduler_hints {
    group = openstack_compute_servergroup_v2.worker[each.value.server_group_key].id
  }

  depends_on = [openstack_networking_router_interface_v2.cluster]
}
