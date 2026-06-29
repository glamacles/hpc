# The VMs + floating IPs.

locals {
  # Expand each instructor x their vms count into a flat map of node objects.
  # The FIRST VM always keeps the bare name; additional VMs are -2, -3, ...
  #   vms = 1 -> key "rachel"                 (VM glamacles-rachel)
  #   vms = 2 -> keys "rachel", "rachel-2"    (VMs glamacles-rachel, -rachel-2)
  # Because the first key never changes, raising `vms` only ADDS nodes — it never
  # renames/destroys the existing VM, so you can scale an instructor up mid-course
  # without disturbing their running server.
  node_list = flatten([
    for name, cfg in var.instructors : [
      for i in range(cfg.vms) : {
        key        = i == 0 ? name : "${name}-${i + 1}"
        vm_name    = i == 0 ? "glamacles-${name}" : "glamacles-${name}-${i + 1}"
        instructor = name
        # contents of the instructor's requirements file, or "" if none
        requirements = cfg.requirements != null ? file("${path.module}/${cfg.requirements}") : ""
      }
    ]
  ])
  nodes = { for n in local.node_list : n.key => n }

  # SSH keys added to every VM (keys/shared/*.pub), reused from the repo's keys/.
  keys_dir    = "${path.module}/../keys"
  shared_keys = [for f in fileset(local.keys_dir, "shared/*.pub") : trimspace(file("${local.keys_dir}/${f}"))]

  # HTTPS hostnames: <node>.<dns_base>.<dns_zone> (or <node>.<dns_zone> if no base).
  dns_suffix = var.dns_base != "" ? "${var.dns_base}.${var.dns_zone}" : var.dns_zone
  hostnames  = { for k, n in local.nodes : k => "${k}.${local.dns_suffix}" }
}

# Explicit port per VM so we have a stable port_id for the floating IP and the
# security group reliably binds (auto-created ports don't expose port_id well).
resource "openstack_networking_port_v2" "vm" {
  for_each           = local.nodes
  name               = "glamacles-${each.key}-port"
  network_id         = openstack_networking_network_v2.net.id
  security_group_ids = [openstack_networking_secgroup_v2.sg.id]

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet.id
  }
}

resource "openstack_compute_instance_v2" "vm" {
  for_each    = local.nodes
  name        = each.value.vm_name
  image_name  = var.image
  flavor_name = var.flavor
  key_pair    = openstack_compute_keypair_v2.admin.name
  # security group is on the port (openstack_networking_port_v2.vm), not here.

  user_data = templatefile("${path.module}/cloud-init/instructor-vm.yaml.tftpl", {
    instructor          = each.value.instructor
    common_mount        = var.common_mount
    scratch_mount       = var.scratch_mount
    common_path         = openstack_sharedfilesystem_share_v2.common.export_locations[0].path
    common_key          = openstack_sharedfilesystem_share_access_v2.common_rw.access_key
    common_access_name  = var.common_rw_rule
    scratch_path        = openstack_sharedfilesystem_share_v2.scratch[each.value.instructor].export_locations[0].path
    scratch_key         = openstack_sharedfilesystem_share_access_v2.scratch[each.value.instructor].access_key
    scratch_access_name = "glamacles-scratch-${each.value.instructor}-rw"
    # optional per-instructor pip requirements baked into the shared venv
    requirements = each.value.requirements
    cull_timeout = var.cull_timeout
    # optional HTTPS (TLJH Let's Encrypt for this VM's hostname)
    enable_https      = tostring(var.enable_https)
    hostname          = var.enable_https ? local.hostnames[each.key] : ""
    letsencrypt_email = var.letsencrypt_email
    # instructor's own key (keys/<username>.pub, if present) + shared keys
    ssh_keys = concat(
      fileexists("${local.keys_dir}/${each.value.instructor}.pub") ? [trimspace(file("${local.keys_dir}/${each.value.instructor}.pub"))] : [],
      local.shared_keys
    )
  })

  network {
    port = openstack_networking_port_v2.vm[each.key].id
  }

  # Subnet must be attached to the router before the VM can reach the internet
  # for its cloud-init build (uv/pip/TLJH downloads).
  depends_on = [openstack_networking_router_interface_v2.ri]
}

resource "openstack_networking_floatingip_v2" "fip" {
  for_each = local.nodes
  pool     = var.public_network
}

resource "openstack_networking_floatingip_associate_v2" "fip" {
  for_each    = local.nodes
  floating_ip = openstack_networking_floatingip_v2.fip[each.key].address
  port_id     = openstack_networking_port_v2.vm[each.key].id
}
