# Edit this for your deployment.
os_cloud = "openstack"

# One entry per instructor (the key is their username = TLJH admin / sudo user,
# and selects keys/<username>.pub for SSH).
#   vms          - how many VMs they need (default 1)
#   requirements - optional pip requirements file (path relative to terraform/),
#                  installed into the shared venv on ALL of that instructor's VMs
#
# Test deployment (one VM, no extras):
instructors = {
  jdowns = { vms = 1 }
  dbrinkerhoff = {vms = 1}
  cgong = { vms = 1}
  mperego = { vms = 1 }
  dcheng = { vms = 1 }
  ylai = { vms = 1 }
}

# Live example — six instructors, some with extra VMs / requirements:
# instructors = {
#   jake = { vms = 2 }                                          # 1 VM
#   doug = { vms = 1 }                                
# }

# Small sizes for testing; raise for the live dataset / project outputs.
common_size_gb  = 600
scratch_size_gb = 60

# admin_pubkey = "~/.ssh/id_ed25519.pub"   # uncomment to override
# cull_timeout = 14400   # idle JupyterLab shutdown, seconds (default 4h; 0 = never)

# ---- HTTPS via Cloudflare (optional) ---------------------------------------
# Requires CLOUDFLARE_API_TOKEN in your environment (Zone:DNS:Edit + Zone:Read).
# Each VM gets <node>.<dns_base>.<dns_zone> -> its IP, with a Let's Encrypt cert.
enable_https      = true
dns_zone          = "geoml.net"      # your Cloudflare zone
dns_base          = "glamacles"        # => jake-1.glamacles.example.org ("" => jake-1.example.org)
letsencrypt_email = "jacob.downs@umt.edu"
