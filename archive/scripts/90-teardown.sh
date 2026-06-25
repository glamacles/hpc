#!/usr/bin/env bash
# 90-teardown.sh — delete the VMs and release their floating IPs.
#
#   ./scripts/90-teardown.sh            # delete VMs + floating IPs only
#   ./scripts/90-teardown.sh --shares   # ALSO delete the Manila shares (DATA LOSS)
#   ./scripts/90-teardown.sh --all      # VMs, IPs, shares, network, secgroup, keypair
#
# Shares and network are kept by default so you can stop/restart the school
# cheaply. To pause SU charges WITHOUT losing anything, prefer shelving instead
# (see README "Controlling SU burn") — this script deletes.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$HERE/config.sh"; source "$HERE/lib.sh"

MODE="${1:-vms}"

delete_node() {                    # <name>
  local name="$1" fip
  exists server "$name" || { log "no server $name"; return; }
  # release floating IPs attached to this server first
  for fip in $(osc server show "$name" -f json \
      | python3 -c "import sys,json;a=json.load(sys.stdin).get('addresses',{});\
import re;print('\n'.join(re.findall(r'[0-9]+(?:\.[0-9]+){3}', str(a))))" \
      | sort -u); do
    if osc floating ip show "$fip" >/dev/null 2>&1; then
      log "deleting floating ip $fip"; osc floating ip delete "$fip" || true
    fi
  done
  log "deleting server $name"
  osc server delete --wait "$name"
}

teardown_project() {               # <label> <instructor>
  local label="$1" name
  while read -r name; do delete_node "$name"; done < <(node_names "$label")
}
for_each_project teardown_project

if [[ "$MODE" == "--shares" || "$MODE" == "--all" ]]; then
  warn "deleting Manila shares — this destroys all stored data"
  del_scratch() { local s; s="$(scratch_share_name "$1")"; exists share "$s" && osc share delete "$s" || true; }
  for_each_project del_scratch
  exists share "$COMMON_SHARE" && osc share delete "$COMMON_SHARE" || true
fi

if [[ "$MODE" == "--all" ]]; then
  log "removing network, security group, keypair"
  osc router remove subnet "$ROUTER" "$SUBNET" 2>/dev/null || true
  osc router unset --external-gateway "$ROUTER" 2>/dev/null || true
  osc router delete "$ROUTER" 2>/dev/null || true
  osc subnet delete "$SUBNET" 2>/dev/null || true
  osc network delete "$NETWORK" 2>/dev/null || true
  osc security group delete "$SECGROUP" 2>/dev/null || true
  osc keypair delete "$KEYPAIR_NAME" 2>/dev/null || true
fi

log "teardown ($MODE) complete"
