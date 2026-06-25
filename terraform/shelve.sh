#!/usr/bin/env bash
# Shelve / unshelve all GLAMacles VMs to control SU burn.
#
#   ./shelve.sh shelve     # stop SU accrual (preserves disk, floating IP, state)
#   ./shelve.sh unshelve   # bring them back (a few min; /data re-mounts)
#   ./shelve.sh status     # show each VM's power state
#
# Operates on every server named glamacles-* in the project. Independent of
# Terraform state — safe to run anytime; `terraform plan` won't fight it.
#
# Needs OpenStack auth: either OS_CLIENT_CONFIG_FILE pointing at your clouds.yaml
# (same as Terraform), or a sourced openrc. Override the cloud name with
# OS_CLOUD if yours isn't "openstack".
set -euo pipefail

OS_CLOUD="${OS_CLOUD:-openstack}"
ACTION="${1:-status}"

# If a clouds.yaml-style cloud is in use, pass --os-cloud; otherwise rely on the
# sourced openrc environment.
osc() {
  if [[ -n "${OS_AUTH_URL:-}" ]]; then openstack "$@"; else openstack --os-cloud "$OS_CLOUD" "$@"; fi
}

vms() { osc server list -f value -c Name | grep '^glamacles-' || true; }

case "$ACTION" in
  shelve)
    for s in $(vms); do echo "shelving $s";   osc server shelve "$s"; done ;;
  unshelve)
    for s in $(vms); do echo "unshelving $s"; osc server unshelve "$s"; done ;;
  status)
    osc server list -f value -c Name -c Status | grep '^glamacles-' || echo "no glamacles VMs found" ;;
  *)
    echo "usage: $0 {shelve|unshelve|status}" >&2; exit 1 ;;
esac
