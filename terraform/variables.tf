# Deployment settings. Override values in terraform.tfvars.

variable "os_cloud" {
  description = "Cloud name in clouds.yaml"
  type        = string
  default     = "openstack"
}

# ---- The VMs ---------------------------------------------------------------
# Keyed by instructor username. That username is the TLJH admin / sudo user,
# selects keys/<username>.pub for SSH, and names the VM (glamacles-<username>)
# and scratch share (glamacles-scratch-<username>).
#   vms          - how many VMs this instructor needs (default 1). >1 share the
#                  same scratch share and the same requirements.
#   requirements - optional path (relative to terraform/) to a pip requirements
#                  file installed into the shared venv on all of this
#                  instructor's VMs, so multi-VM setups come up identical.
variable "instructors" {
  description = "Map of instructor username => { vms, requirements }"
  type = map(object({
    vms          = optional(number, 1)
    requirements = optional(string)
  }))
}

variable "flavor" {
  description = "GPU flavor. g3.large = 16 vCPU / 60 GB / 50% A100 (20 GB VRAM) / 32 SU/hr."
  type        = string
  default     = "g3.large"
}

variable "image" {
  description = "Featured image with NVIDIA/vGPU drivers preinstalled."
  type        = string
  default     = "Featured-Ubuntu24"
}

variable "keypair_name" {
  type    = string
  default = "glamacles-admin"
}

# How long (seconds) an idle JupyterLab server stays up before TLJH culls it.
# TLJH default is 3600 (1h); 14400 = 4h avoids surprise "server not running"
# pages during breaks. Busy kernels are never culled. Longer = idle kernels hold
# shared GPU memory longer. Set 0 to never cull (not recommended on a shared GPU).
variable "cull_timeout" {
  type    = number
  default = 14400
}

variable "admin_pubkey" {
  description = "Path to your admin SSH public key (injected as the ubuntu user)."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# ---- Network ---------------------------------------------------------------
variable "public_network" {
  type    = string
  default = "public"
}
variable "secgroup" {
  type    = string
  default = "glamacles-sg"
}
variable "network" {
  type    = string
  default = "glamacles-net"
}
variable "subnet" {
  type    = string
  default = "glamacles-subnet"
}
variable "router" {
  type    = string
  default = "glamacles-router"
}
variable "subnet_cidr" {
  type    = string
  default = "10.10.10.0/24"
}

# ---- Shared storage (Manila CephFS) ----------------------------------------
variable "share_type" {
  type    = string
  default = "cephfsnativetype"
}
variable "common_share" {
  type    = string
  default = "glamacles-common"
}
variable "common_size_gb" {
  type    = number
  default = 2000
}
variable "common_mount" {
  type    = string
  default = "/data/common"
}
variable "scratch_size_gb" {
  type    = number
  default = 500
}
variable "scratch_mount" {
  type    = string
  default = "/data/scratch"
}
variable "common_rw_rule" {
  type    = string
  default = "glamacles-common-rw"
}
variable "common_ro_rule" {
  type    = string
  default = "glamacles-common-ro"
}

# ---- HTTPS (optional, via Cloudflare DNS + Let's Encrypt) ------------------
# When enabled, each VM gets a Cloudflare A record (<node>.<dns_base>.<dns_zone>)
# pointing at its floating IP, and enables TLJH Let's Encrypt for that hostname.
# Requires CLOUDFLARE_API_TOKEN in the environment.
variable "enable_https" {
  type    = bool
  default = false
}
variable "dns_zone" {
  description = "Cloudflare zone the records live in, e.g. example.org"
  type        = string
  default     = ""
}
variable "dns_base" {
  description = "Optional sub-label under the zone. \"glamacles\" => rachel.glamacles.example.org; \"\" => rachel.example.org"
  type        = string
  default     = ""
}
variable "letsencrypt_email" {
  description = "Contact email for Let's Encrypt (expiry notices)"
  type        = string
  default     = ""
}
variable "cloudflare_api_token" {
  description = "Cloudflare API token (Zone:DNS:Edit + Zone:Read). Set in a gitignored secret.auto.tfvars, or leave empty to use the CLOUDFLARE_API_TOKEN env var."
  type        = string
  default     = ""
  sensitive   = true
}
