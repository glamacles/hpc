# Cloudflare DNS records for HTTPS. Only created when enable_https = true.
# Each VM gets an A record at its hostname pointing to its floating IP; TLJH
# (via cloud-init) then obtains a Let's Encrypt cert for that hostname.

data "cloudflare_zone" "z" {
  count = var.enable_https ? 1 : 0
  name  = var.dns_zone
}

resource "cloudflare_record" "vm" {
  for_each = var.enable_https ? local.nodes : {}

  zone_id = data.cloudflare_zone.z[0].id
  name    = local.hostnames[each.key]
  type    = "A"
  content = openstack_networking_floatingip_v2.fip[each.key].address
  ttl     = 120

  # MUST be DNS-only (grey cloud). If Cloudflare proxies the record, it
  # terminates TLS itself and the Let's Encrypt HTTP-01 challenge to the VM
  # fails (and JupyterHub websockets would need extra proxy config).
  proxied = false
}
