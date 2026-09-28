data "openstack_images_image_v2" "node" {
  count       = var.image_id == null ? 1 : 0
  name        = coalesce(var.image_name, "__image_name_or_image_id_is_required__")
  most_recent = true
}

data "openstack_compute_flavor_v2" "control_plane" {
  name = var.control_plane_flavor_name
}

data "openstack_compute_flavor_v2" "worker" {
  name = var.worker_flavor_name
}

data "openstack_networking_network_v2" "external" {
  count = local.need_external_network ? 1 : 0
  name  = coalesce(var.external_network_name, "__external_network_name_is_required__")
}

data "openstack_networking_network_v2" "existing" {
  count = var.create_network ? 0 : 1
  name  = coalesce(var.existing_network_name, "__existing_network_name_is_required__")
}

data "openstack_networking_subnet_v2" "existing" {
  count      = var.create_network ? 0 : 1
  name       = coalesce(var.existing_subnet_name, "__existing_subnet_name_is_required__")
  network_id = data.openstack_networking_network_v2.existing[0].id
}
