#!/usr/bin/env bash
# 00-prereqs.sh — one-time setup: keypair, security group, private network/router.
# Safe to re-run; each step is skipped if the resource already exists.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$HERE/config.sh"; source "$HERE/lib.sh"

# --- SSH keypair (the admin/bootstrap key injected as the `ubuntu` user) ------
if exists keypair "$KEYPAIR_NAME"; then
  log "keypair $KEYPAIR_NAME exists"
else
  [[ -f "$ADMIN_PUBKEY" ]] || die "ADMIN_PUBKEY not found: $ADMIN_PUBKEY (generate with ssh-keygen)"
  log "creating keypair $KEYPAIR_NAME from $ADMIN_PUBKEY"
  osc keypair create --public-key "$ADMIN_PUBKEY" "$KEYPAIR_NAME"
fi

# --- Security group: SSH + JupyterHub (HTTP/HTTPS) ----------------------------
if exists "security group" "$SECGROUP"; then
  log "security group $SECGROUP exists"
else
  log "creating security group $SECGROUP"
  osc security group create "$SECGROUP" --description "GLAMacles: ssh + jupyterhub"
  for spec in "22:tcp" "80:tcp" "443:tcp"; do
    port="${spec%%:*}"; proto="${spec##*:}"
    osc security group rule create --proto "$proto" --dst-port "$port" --remote-ip 0.0.0.0/0 "$SECGROUP"
  done
fi

# --- Private network + subnet + router to the public network -----------------
if exists network "$NETWORK"; then
  log "network $NETWORK exists"
else
  log "creating network/subnet/router"
  osc network create "$NETWORK"
  osc subnet create "$SUBNET" --network "$NETWORK" --subnet-range "$SUBNET_CIDR" \
    --dns-nameserver 8.8.8.8 --dns-nameserver 1.1.1.1
  osc router create "$ROUTER"
  osc router set "$ROUTER" --external-gateway "$PUBLIC_NETWORK"
  osc router add subnet "$ROUTER" "$SUBNET"
fi

log "prerequisites ready. Next: ./scripts/10-create-shares.sh"
