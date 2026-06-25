terraform {
  required_version = ">= 1.3"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Authenticates from clouds.yaml (the file you downloaded from Horizon).
# Terraform/gophercloud searches ./clouds.yaml, ~/.config/openstack/, /etc/openstack/.
# var.os_cloud must match the cloud name in that file (default "openstack").
provider "openstack" {
  cloud = var.os_cloud
}

# Only used when enable_https = true. The token comes from var.cloudflare_api_token
# (set it in a gitignored secret.auto.tfvars — see secret.auto.tfvars.example); if
# that's empty, the provider falls back to the CLOUDFLARE_API_TOKEN env variable.
# Needs Zone:DNS:Edit + Zone:Read on your zone.
provider "cloudflare" {
  api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : null
}
