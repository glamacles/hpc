#!/usr/bin/env bash
# 50-power.sh — shelve/unshelve all project VMs to control SU burn.
#
#   ./scripts/50-power.sh shelve     # stop SU charges (preserves disk + IP)
#   ./scripts/50-power.sh unshelve   # bring them back (a few min to resume)
#   ./scripts/50-power.sh status     # show power state of each VM
#
# Shelving is the right way to "turn off" VMs overnight/weekends without
# rebuilding: SU accrual stops, /data shares re-mount automatically on unshelve.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$HERE/config.sh"; source "$HERE/lib.sh"

ACTION="${1:-status}"
each_node() {                      # run <fn> against every node name
  local f="$1" entry l n
  for entry in "${PROJECTS[@]}"; do
    l="${entry%%:*}"
    while read -r n; do "$f" "$n"; done < <(node_names "$l")
  done
}

do_shelve()   { exists server "$1" && { log "shelving $1";   osc server shelve "$1"; }; }
do_unshelve() { exists server "$1" && { log "unshelving $1"; osc server unshelve "$1"; }; }
do_status()   { exists server "$1" && printf '%-28s %s\n' "$1" "$(osc server show "$1" -f value -c status)"; }

case "$ACTION" in
  shelve)   each_node do_shelve ;;
  unshelve) each_node do_unshelve ;;
  status)   each_node do_status ;;
  *) die "usage: $0 {shelve|unshelve|status}" ;;
esac
