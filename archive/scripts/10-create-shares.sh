#!/usr/bin/env bash
# 10-create-shares.sh — create the common (read-only) dataset share and one
# read-write scratch share per project. Idempotent.
#
# Result layout, mounted on every project VM by cloud-init:
#   /data/common   <- COMMON_SHARE, read-only everywhere
#   /data/scratch  <- per-project scratch, read-write (shared by that project's VMs)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$HERE/config.sh"; source "$HERE/lib.sh"

create_share() {           # <name> <size_gb>
  local name="$1" size="$2"
  if exists share "$name"; then
    log "share $name exists"
  else
    log "creating share $name (${size} GB)"
    osc share create --share-type "$SHARE_TYPE" --name "$name" cephfs "$size"
  fi
}

add_access() {             # <share> <rule_name> <rw|ro>
  local share="$1" rule="$2" level="$3"
  if osc share access list "$share" -f value -c "Access To" 2>/dev/null | grep -qx "$rule"; then
    log "access rule $rule on $share exists"
  else
    log "granting $level access '$rule' on $share"
    osc share access create --access-level "$level" "$share" cephx "$rule"
  fi
}

# --- Common dataset share ----------------------------------------------------
create_share "$COMMON_SHARE" "$COMMON_SIZE_GB"
add_access "$COMMON_SHARE" "$COMMON_RW_RULE" rw   # for you, to upload data
add_access "$COMMON_SHARE" "$COMMON_RO_RULE" ro   # mounted on every VM

# --- Per-project scratch shares ----------------------------------------------
make_scratch() {           # <label> <instructor>
  local label="$1" name; name="$(scratch_share_name "$label")"
  create_share "$name" "$SCRATCH_SIZE_GB"
  add_access "$name" "glamacles-scratch-${label}-rw" rw
}
for_each_project make_scratch

# Manila provisioning is async; wait for shares to become 'available'.
log "waiting for shares to become available..."
for try in $(seq 1 30); do
  if ! osc share list -f value -c Status | grep -qvx available; then
    log "all shares available"; break
  fi
  sleep 10
done

cat <<EOF

Shares created. To load data into the common share, mount it read-write on any
JS2 VM using rule '$COMMON_RW_RULE' (see README "Loading the shared dataset").

Next: ./scripts/20-launch-vms.sh
EOF
