resource "terraform_data" "invariants" {
  input = var.cluster_name

  lifecycle {
    precondition {
      condition     = (var.image_id == null) != (var.image_name == null)
      error_message = "Set exactly one of image_id or image_name. Pinning image_id is recommended for production."
    }

    precondition {
      condition = var.create_network || (
        var.existing_network_name != null && var.existing_subnet_name != null
      )
      error_message = "existing_network_name and existing_subnet_name are required when create_network is false."
    }

    precondition {
      condition     = var.create_network || data.openstack_networking_subnet_v2.existing[0].ip_version == 4
      error_message = "The existing subnet must be IPv4; this stack currently creates IPv4 security-group and load-balancer rules."
    }

    precondition {
      condition     = !local.need_external_network || var.external_network_name != null
      error_message = "external_network_name is required when creating a router or a floating IP."
    }

    precondition {
      condition     = !var.create_api_floating_ip || var.create_api_load_balancer
      error_message = "create_api_floating_ip requires create_api_load_balancer = true."
    }

    precondition {
      condition     = !var.create_api_floating_ip || length(var.api_allowed_cidrs) > 0
      error_message = "api_allowed_cidrs must not be empty when create_api_floating_ip is true."
    }

    precondition {
      condition     = !var.create_bootstrap_floating_ip || length(var.ssh_allowed_cidrs) > 0
      error_message = "ssh_allowed_cidrs must not be empty when create_bootstrap_floating_ip is true."
    }
  }
}
