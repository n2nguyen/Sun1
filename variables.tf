variable "region" {
  description = "OpenStack region. Leave null to use OS_REGION_NAME."
  type        = string
  default     = null
  nullable    = true
}

variable "cluster_name" {
  description = "Prefix used for every resource and VM hostname."
  type        = string
  default     = "nextcloud-k8s"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,40}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must contain 3-42 lowercase letters, digits, or hyphens."
  }
}

variable "image_name" {
  description = "Exact name of a cloud-init capable Ubuntu image in Glance. Use only when image_id is null."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.image_name == null ? true : length(trimspace(var.image_name)) > 0
    error_message = "image_name must be null or a non-empty string."
  }
}

variable "image_id" {
  description = "Immutable Glance image ID for all nodes. Preferred over image_name for production."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.image_id == null ? true : length(trimspace(var.image_id)) > 0
    error_message = "image_id must be null or a non-empty string."
  }
}

variable "control_plane_flavor_name" {
  description = "OpenStack flavor for control-plane nodes; start around 8 vCPU and 16-32 GiB RAM."
  type        = string

  validation {
    condition     = length(trimspace(var.control_plane_flavor_name)) > 0
    error_message = "control_plane_flavor_name must not be empty."
  }
}

variable "worker_flavor_name" {
  description = "OpenStack flavor for workers; the proposed Nextcloud seed size is around 32 vCPU and 128 GiB RAM."
  type        = string

  validation {
    condition     = length(trimspace(var.worker_flavor_name)) > 0
    error_message = "worker_flavor_name must not be empty."
  }
}

variable "keypair_name" {
  description = "Name of an existing OpenStack SSH key pair."
  type        = string

  validation {
    condition     = length(trimspace(var.keypair_name)) > 0
    error_message = "keypair_name must not be empty."
  }
}

variable "ssh_user" {
  description = "Default SSH user provided by the selected cloud image."
  type        = string
  default     = "ubuntu"
}

variable "availability_zones" {
  description = "Compute availability zones over which nodes are distributed round-robin."
  type        = list(string)
  default     = ["nova"]

  validation {
    condition     = length(var.availability_zones) > 0 && alltrue([for az in var.availability_zones : length(trimspace(az)) > 0])
    error_message = "At least one non-empty availability zone is required."
  }
}

variable "control_plane_count" {
  description = "Number of Kubernetes control-plane nodes. Keep this odd for etcd quorum."
  type        = number
  default     = 3

  validation {
    condition     = var.control_plane_count >= 3 && floor(var.control_plane_count) == var.control_plane_count && var.control_plane_count % 2 == 1
    error_message = "control_plane_count must be an odd number greater than or equal to 3."
  }
}

variable "worker_count" {
  description = "Number of application worker nodes. Increase this value to scale the initial node pool."
  type        = number
  default     = 3

  validation {
    condition     = var.worker_count >= 1 && floor(var.worker_count) == var.worker_count
    error_message = "worker_count must be at least 1."
  }
}

variable "control_plane_server_group_policy" {
  description = "Nova server-group policy for control-plane nodes."
  type        = string
  default     = "anti-affinity"

  validation {
    condition     = contains(["anti-affinity", "soft-anti-affinity"], var.control_plane_server_group_policy)
    error_message = "Use anti-affinity or soft-anti-affinity."
  }
}

variable "worker_server_group_policy" {
  description = "Nova server-group policy for workers. Use anti-affinity only if at least three hypervisors are available."
  type        = string
  default     = "soft-anti-affinity"

  validation {
    condition     = contains(["anti-affinity", "soft-anti-affinity"], var.worker_server_group_policy)
    error_message = "Use anti-affinity or soft-anti-affinity."
  }
}

variable "worker_server_group_size" {
  description = "Maximum workers per Nova server group. Sharding avoids the common server_group_members quota when the pool grows."
  type        = number
  default     = 10

  validation {
    condition     = var.worker_server_group_size >= 1 && floor(var.worker_server_group_size) == var.worker_server_group_size
    error_message = "worker_server_group_size must be a positive integer."
  }
}

variable "boot_from_volume" {
  description = "Boot instances from persistent Cinder volumes instead of Nova ephemeral disks."
  type        = bool
  default     = true
}

variable "control_plane_root_volume_size" {
  description = "Control-plane root volume size in GiB when boot_from_volume is true."
  type        = number
  default     = 100

  validation {
    condition     = var.control_plane_root_volume_size >= 40
    error_message = "Control-plane root volumes must be at least 40 GiB."
  }
}

variable "worker_root_volume_size" {
  description = "Worker root volume size in GiB when boot_from_volume is true."
  type        = number
  default     = 200

  validation {
    condition     = var.worker_root_volume_size >= 80
    error_message = "Worker root volumes must be at least 80 GiB."
  }
}

variable "create_network" {
  description = "Create a dedicated Neutron network, subnet, and router. Set false to use an existing network."
  type        = bool
  default     = true
}

variable "network_name" {
  description = "Name of the Neutron network created by this stack."
  type        = string
  default     = "nextcloud-k8s-network"
}

variable "subnet_name" {
  description = "Name of the Neutron subnet created by this stack."
  type        = string
  default     = "nextcloud-k8s-subnet"
}

variable "router_name" {
  description = "Name of the Neutron router created by this stack."
  type        = string
  default     = "nextcloud-k8s-router"
}

variable "node_subnet_cidr" {
  description = "IPv4 CIDR of the node network. When reusing a network, this must match its real CIDR."
  type        = string
  default     = "10.20.0.0/24"

  validation {
    condition     = can(cidrnetmask(var.node_subnet_cidr))
    error_message = "node_subnet_cidr must be a valid IPv4 CIDR."
  }
}

variable "dns_nameservers" {
  description = "DNS resolvers assigned to instances by DHCP."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "external_network_name" {
  description = "Exact name of the external/public Neutron network used by the router and optional floating IPs."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.external_network_name == null ? true : length(trimspace(var.external_network_name)) > 0
    error_message = "external_network_name must be null or a non-empty string."
  }
}

variable "existing_network_name" {
  description = "Existing Neutron network name; required only when create_network is false."
  type        = string
  default     = null
  nullable    = true
}

variable "existing_subnet_name" {
  description = "Existing Neutron subnet name; required only when create_network is false."
  type        = string
  default     = null
  nullable    = true
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH to the first control-plane floating IP. Keep empty when no bootstrap floating IP is needed."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.ssh_allowed_cidrs : can(cidrnetmask(cidr))])
    error_message = "Every ssh_allowed_cidrs item must be a valid IPv4 CIDR."
  }
}

variable "api_allowed_cidrs" {
  description = "Additional IPv4 CIDRs allowed to access the Kubernetes API load balancer. The node subnet is always included automatically."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.api_allowed_cidrs : can(cidrnetmask(cidr))])
    error_message = "Every api_allowed_cidrs item must be a valid IPv4 CIDR."
  }
}

variable "create_api_load_balancer" {
  description = "Create an Octavia TCP load balancer for the highly available Kubernetes API endpoint."
  type        = bool
  default     = true
}

variable "api_load_balancer_flavor_id" {
  description = "Optional Octavia flavor ID. Select a provider flavor that offers HA/ACTIVE_STANDBY where available."
  type        = string
  default     = null
  nullable    = true
}

variable "api_load_balancer_availability_zone" {
  description = "Optional Octavia availability-zone name. HA depends on the selected Octavia provider, flavor, and cloud topology."
  type        = string
  default     = null
  nullable    = true
}

variable "api_load_balancer_provider" {
  description = "Optional Octavia provider name, for example amphora or ovn. Null uses the cloud default."
  type        = string
  default     = null
  nullable    = true
}

variable "api_listener_idle_timeout_ms" {
  description = "Octavia client/member inactivity timeout in milliseconds. Long-lived Kubernetes watch/log/exec connections need much more than common 50-second defaults."
  type        = number
  default     = 3600000

  validation {
    condition     = var.api_listener_idle_timeout_ms >= 60000 && floor(var.api_listener_idle_timeout_ms) == var.api_listener_idle_timeout_ms
    error_message = "api_listener_idle_timeout_ms must be an integer of at least 60000 milliseconds."
  }
}

variable "api_listener_connect_timeout_ms" {
  description = "Octavia timeout in milliseconds when connecting to a kube-apiserver member."
  type        = number
  default     = 5000

  validation {
    condition     = var.api_listener_connect_timeout_ms >= 1000 && floor(var.api_listener_connect_timeout_ms) == var.api_listener_connect_timeout_ms
    error_message = "api_listener_connect_timeout_ms must be an integer of at least 1000 milliseconds."
  }
}

variable "api_dns_name" {
  description = "Optional DNS name resolving to the API private VIP or floating IP. Preferred over embedding an IP in kubeadm certificates."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.api_dns_name == null ? true : can(regex(
      "^([a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)*[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$",
      var.api_dns_name,
    ))
    error_message = "api_dns_name must be null or a valid DNS name without scheme or port."
  }
}

variable "create_api_floating_ip" {
  description = "Associate a public floating IP with the API load balancer. Requires create_api_load_balancer and non-empty api_allowed_cidrs."
  type        = bool
  default     = false
}

variable "create_bootstrap_floating_ip" {
  description = "Associate a temporary/admin floating IP with the first control-plane node. Requires non-empty ssh_allowed_cidrs."
  type        = bool
  default     = false
}

variable "prepare_kubernetes_os" {
  description = "Use cloud-init to install base tools, disable swap, load kernel modules, and configure Kubernetes sysctls."
  type        = bool
  default     = true
}

variable "timezone" {
  description = "Timezone configured by cloud-init."
  type        = string
  default     = "Asia/Bangkok"
}

variable "resource_tags" {
  description = "Metadata copied to compute instances."
  type        = map(string)
  default = {
    environment = "production"
    service     = "nextcloud"
    managed_by  = "terraform"
  }
}
