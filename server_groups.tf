resource "openstack_compute_servergroup_v2" "control_plane" {
  name     = "${var.cluster_name}-control-plane"
  policies = [var.control_plane_server_group_policy]
}

resource "openstack_compute_servergroup_v2" "worker" {
  for_each = local.worker_server_groups

  name     = each.value
  policies = [var.worker_server_group_policy]
}
