# config.sh — central configuration for the GLAMacles Jetstream2 deployment.
# Sourced by every script in scripts/. Edit values here; avoid editing the scripts.

# ---- OpenStack / Jetstream2 ------------------------------------------------
# Name of the cloud entry in clouds.yaml (see clouds.yaml.example). If you use a
# downloaded openrc.sh instead, leave this and just `source openrc-*.sh` first.
export OS_CLOUD="${OS_CLOUD:-openstack}"

# Jetstream2 external (public) network used for floating IPs.
export PUBLIC_NETWORK="public"

# Manila CephFS share type on Jetstream2.
export SHARE_TYPE="cephfsnativetype"

# ---- The VMs ---------------------------------------------------------------
# One VM per project. The label becomes part of the VM name, the per-project
# scratch share name, and the TLJH admin (instructor) username.
# Format: "label:instructor_username"  (username = TLJH admin / Linux sudo user)
PROJECTS=(
  "stuff:jake"
)

# Number of VMs to launch PER project/instructor. 1 = one shared TLJH hub per
# project (recommended default). 2 = two VMs per project that SHARE the same
# read-write scratch share, so you can split students across two GPU slices to
# cut contention. See README "How many VMs per instructor?" before raising this.
# (g3.xl full-GPU instances are rarely available on JS2, so 2x g3.large is the
# practical way to give a project more GPU.)
export NODES_PER_PROJECT="${NODES_PER_PROJECT:-1}"

# GPU flavor: g3.large = 16 vCPU / 60 GB RAM / 50% A100 (20 GB VRAM) / 32 SU/hr.
export FLAVOR="g3.large"

# Featured image with NVIDIA/vGPU drivers preinstalled.
export IMAGE="Featured-Ubuntu24"

# Name of the SSH keypair to register in OpenStack and inject as the default
# `ubuntu` login (admin bootstrap key). Public key path below.
export KEYPAIR_NAME="glamacles-admin"
export ADMIN_PUBKEY="${HOME}/.ssh/id_ed25519.pub"

# Security group created by 00-prereqs.sh.
export SECGROUP="glamacles-sg"

# Private network/subnet/router created by 00-prereqs.sh.
export NETWORK="glamacles-net"
export SUBNET="glamacles-subnet"
export ROUTER="glamacles-router"
export SUBNET_CIDR="10.10.10.0/24"

# ---- Shared storage (Manila CephFS) ----------------------------------------
# One common read-only dataset share mounted on every VM at $COMMON_MOUNT,
# plus one read-write scratch share per project at $SCRATCH_MOUNT.
export COMMON_SHARE="glamacles-common"        # holds shared training data
export COMMON_SIZE_GB=20                     # adjust to your dataset volume
export COMMON_MOUNT="/data/common"

export SCRATCH_SIZE_GB=50                      # per project
export SCRATCH_MOUNT="/data/scratch"

# Access-rule names (must be globally unique on the cloud; the project label is
# appended for scratch rules inside the scripts).
export COMMON_RW_RULE="glamacles-common-rw"     # for the data curator / you
export COMMON_RO_RULE="glamacles-common-ro"     # mounted read-only on all VMs
