output "cluster_summary" {
  description = "Requested topology."
  value = {
    cluster_name        = var.cluster_name
    control_plane_count = var.control_plane_count
    worker_count        = var.worker_count
    image_id            = local.node_image_id
    network_id          = local.network_id
    subnet_id           = local.subnet_id
  }
}

output "control_plane_nodes" {
  description = "Control-plane instance IDs and private IP addresses."
  value = {
    for key, instance in openstack_compute_instance_v2.control_plane : key => {
      id         = instance.id
      name       = instance.name
      az         = local.control_plane_nodes[key].az
      private_ip = openstack_networking_port_v2.control_plane[key].all_fixed_ips[0]
    }
  }
}

output "worker_nodes" {
  description = "Worker instance IDs and private IP addresses."
  value = {
    for key, instance in openstack_compute_instance_v2.worker : key => {
      id         = instance.id
      name       = instance.name
      az         = local.worker_nodes[key].az
      private_ip = openstack_networking_port_v2.worker[key].all_fixed_ips[0]
    }
  }
}

output "kubernetes_api_endpoint" {
  description = "Stable host:port value for kubeadm controlPlaneEndpoint or the equivalent installer setting."
  value = format(
    "%s:6443",
    local.kubernetes_api_address,
  )
}

output "kubernetes_api_url" {
  description = "HTTPS URL for human/API-client use; do not use this value as kubeadm controlPlaneEndpoint."
  value       = "https://${local.kubernetes_api_address}:6443"
}

output "kubernetes_api_private_vip" {
  description = "Private Octavia VIP, or null when the API load balancer is disabled."
  value       = var.create_api_load_balancer ? openstack_lb_loadbalancer_v2.kube_api[0].vip_address : null
}

output "kubernetes_api_floating_ip" {
  description = "Public API floating IP, or null when disabled."
  value       = var.create_api_load_balancer && var.create_api_floating_ip ? openstack_networking_floatingip_v2.kube_api[0].address : null
}

output "bootstrap_floating_ip" {
  description = "Floating IP attached to the first control-plane node, or null when disabled."
  value       = var.create_bootstrap_floating_ip ? openstack_networking_floatingip_v2.bootstrap[0].address : null
}

output "bootstrap_ssh_command" {
  description = "Example SSH command when a bootstrap floating IP is enabled."
  value = var.create_bootstrap_floating_ip ? format(
    "ssh %s@%s",
    var.ssh_user,
    openstack_networking_floatingip_v2.bootstrap[0].address,
  ) : null
}

output "ansible_inventory" {
  description = "Minimal private-IP inventory suitable as a starting point for Kubespray or Ansible."
  value = join("\n", concat(
    ["[kube_control_plane]"],
    [for key in sort(keys(local.control_plane_nodes)) : format(
      "%s ansible_host=%s",
      local.control_plane_nodes[key].name,
      openstack_networking_port_v2.control_plane[key].all_fixed_ips[0],
    )],
    ["", "[etcd:children]", "kube_control_plane", "", "[kube_node]"],
    [for key in sort(keys(local.worker_nodes)) : format(
      "%s ansible_host=%s",
      local.worker_nodes[key].name,
      openstack_networking_port_v2.worker[key].all_fixed_ips[0],
    )],
    [
      "",
      "[k8s_cluster:children]",
      "kube_control_plane",
      "kube_node",
      "",
      "[all:vars]",
      "ansible_user=${var.ssh_user}",
    ],
  ))
}
