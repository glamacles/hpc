#!/usr/bin/env bash
# 20-launch-vms.sh — launch the project VMs. For each project it renders the
# cloud-init template with that project's instructor + share details, boots
# NODES_PER_PROJECT VM(s), and assigns a floating IP to each.
# Re-running skips VMs that already exist.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$HERE/config.sh"; source "$HERE/lib.sh"

TMPL="$HERE/cloud-init/instructor-vm.yaml.tmpl"
BUILD="$HERE/build"; mkdir -p "$BUILD"

log "reading common share details ($COMMON_SHARE)"
COMMON_PATH="$(share_export_path "$COMMON_SHARE")"
COMMON_KEY="$(share_access_key "$COMMON_SHARE" "$COMMON_RO_RULE")"
[[ -n "$COMMON_PATH" && -n "$COMMON_KEY" ]] || die "could not read common share export path/key"

# Render the template by substituting @@TOKENS@@ from the environment (python
# str.replace, so base64 keys and ':/' paths can't break a sed delimiter).
render() {
  python3 - "$TMPL" <<'PY'
import os, sys
tmpl = open(sys.argv[1]).read()
for k in ("INSTRUCTOR","COMMON_MOUNT","SCRATCH_MOUNT","COMMON_PATH","COMMON_KEY",
          "COMMON_ACCESS_NAME","SCRATCH_PATH","SCRATCH_KEY","SCRATCH_ACCESS_NAME",
          "SSH_KEYS_BLOCK"):
    tmpl = tmpl.replace(f"@@{k}@@", os.environ[k])
sys.stdout.write(tmpl)
PY
}

launch_project() {                 # <label> <instructor>
  local label="$1" instructor="$2"
  local scratch; scratch="$(scratch_share_name "$label")"

  log "reading scratch share details ($scratch)"
  export INSTRUCTOR="$instructor"
  export COMMON_MOUNT SCRATCH_MOUNT COMMON_PATH COMMON_KEY
  export COMMON_ACCESS_NAME="$COMMON_RO_RULE"
  export SCRATCH_ACCESS_NAME="glamacles-scratch-${label}-rw"
  export SCRATCH_PATH; SCRATCH_PATH="$(share_export_path "$scratch")"
  export SCRATCH_KEY;  SCRATCH_KEY="$(share_access_key "$scratch" "$SCRATCH_ACCESS_NAME")"
  [[ -n "$SCRATCH_PATH" && -n "$SCRATCH_KEY" ]] || die "scratch share $scratch not ready"
  export SSH_KEYS_BLOCK; SSH_KEYS_BLOCK="$(ssh_keys_block "$instructor")"

  local userdata="$BUILD/cloud-init-${label}.yaml"
  render > "$userdata"

  local name
  while read -r name; do
    if exists server "$name"; then log "server $name exists, skipping"; continue; fi
    log "launching $name (instructor: $instructor)"
    osc server create "$name" \
      --image "$IMAGE" --flavor "$FLAVOR" \
      --network "$NETWORK" --security-group "$SECGROUP" \
      --key-name "$KEYPAIR_NAME" --user-data "$userdata" --wait

    local fip
    fip="$(osc floating ip create "$PUBLIC_NETWORK" -f value -c floating_ip_address)"
    osc server add floating ip "$name" "$fip"
    printf '%-28s instructor=%-10s ip=%s  -> http://%s/\n' "$name" "$instructor" "$fip" "$fip" \
      | tee -a "$BUILD/vm-inventory.txt"
  done < <(node_names "$label")
}

: > "$BUILD/vm-inventory.txt"
for_each_project launch_project

cat <<EOF

All VMs launched. Inventory: $BUILD/vm-inventory.txt
Setup (drivers check, venv build, TLJH) runs via cloud-init and takes ~8-15 min
after boot. Track it on a VM with:
  ssh ubuntu@<ip> 'tail -f /var/log/cloud-init-output.log'
  # done when /opt/glamacles/SETUP_DONE exists
Then browse to http://<ip>/ and log in as the instructor username to set its
password (first login = admin). See README for adding students.
EOF
