# lib.sh — shared helpers. Sourced by the numbered scripts after config.sh.
set -euo pipefail

# Always talk to the right cloud. If the user sourced an openrc.sh, OS_AUTH_URL
# will be set and we leave openstack to use the env; otherwise we rely on OS_CLOUD.
osc() {
  if [[ -n "${OS_AUTH_URL:-}" ]]; then
    openstack "$@"
  else
    openstack --os-cloud "$OS_CLOUD" "$@"
  fi
}

# Manila needs a recent microversion for cephx access keys to appear.
export OS_SHARE_API_VERSION="${OS_SHARE_API_VERSION:-2.63}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Does a named OpenStack resource already exist? Used to make scripts idempotent.
# usage: exists <type> <name>   e.g. exists server glamacles-ice-velocity-1
exists() { osc "$1" show "$2" >/dev/null 2>&1; }

# Iterate projects, calling a function with (label, instructor) for each.
for_each_project() {
  local fn="$1" entry label instructor
  for entry in "${PROJECTS[@]}"; do
    label="${entry%%:*}"
    instructor="${entry##*:}"
    "$fn" "$label" "$instructor"
  done
}

# Per-project node names: one VM -> "<label>", N>1 -> "<label>-1".."<label>-N".
node_names() {
  local label="$1" n
  if (( NODES_PER_PROJECT <= 1 )); then
    echo "glamacles-${label}"
  else
    for n in $(seq 1 "$NODES_PER_PROJECT"); do echo "glamacles-${label}-${n}"; done
  fi
}

scratch_share_name() { echo "glamacles-scratch-$1"; }   # arg: project label

# Build a cloud-init `ssh_authorized_keys:` block from keys/<instructor>.pub and
# any keys/shared/*.pub. Prints empty string if no key files are present.
# Relies on $HERE (set by the calling script).
ssh_keys_block() {
  local instructor="$1" f line any=0 out="ssh_authorized_keys:"
  shopt -s nullglob
  for f in "$HERE/keys/${instructor}.pub" "$HERE"/keys/shared/*.pub; do
    [[ -f "$f" ]] || continue
    while read -r line; do
      [[ -n "$line" && "$line" != \#* ]] && { out+=$'\n'"  - $line"; any=1; }
    done < "$f"
  done
  shopt -u nullglob
  (( any )) && printf '%s\n' "$out" || printf ''
}

# Export (mount) path for a Manila share: "mon_ip:port,...:/volumes/_nogroup/uuid/uuid"
share_export_path() {
  osc share export location list "$1" -f value -c Path | head -n1
}

# cephx access key for a given access-rule name on a share.
share_access_key() {
  local share="$1" rule="$2"
  osc share access list "$share" -f json \
    | python3 -c "import sys,json; \
rows=json.load(sys.stdin); \
print(next(r['access_key'] for r in rows if r['access_to']=='$rule'))"
}
