# `terraform output vms` prints the inventory (name -> ip, JupyterHub URL).
output "vms" {
  description = "Per-VM access info"
  value = {
    for k, n in local.nodes : openstack_compute_instance_v2.vm[k].name => {
      instructor = n.instructor
      ip         = openstack_networking_floatingip_v2.fip[k].address
      jupyterhub = var.enable_https ? "https://${local.hostnames[k]}/" : "http://${openstack_networking_floatingip_v2.fip[k].address}/"
      ssh        = "ssh ubuntu@${openstack_networking_floatingip_v2.fip[k].address}"
    }
  }
}

# For loading the shared dataset: mount the common share read-write once using
# these. `terraform output -raw common_rw_access_key` to reveal the key.
output "common_export_path" {
  description = "CephFS mount path for the common share"
  value       = openstack_sharedfilesystem_share_v2.common.export_locations[0].path
}

output "common_rw_access_key" {
  description = "cephx key for the common-share read-write rule (for data upload)"
  value       = openstack_sharedfilesystem_share_access_v2.common_rw.access_key
  sensitive   = true
}
