provider "openstack" {
  # Authentication is intentionally read from OS_* environment variables.
  # Source an OpenStack RC file before running Terraform.
  region = var.region
}

