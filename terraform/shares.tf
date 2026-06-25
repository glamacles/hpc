# Manila CephFS shares.
# Terraform waits for each share to reach "available" before exposing its
# export_locations, and surfaces the cephx access_key directly as an attribute
# (no CLI parsing needed). Both feed into the cloud-init in compute.tf.

# ---- Common dataset share (read-write on every VM) -------------------------
resource "openstack_sharedfilesystem_share_v2" "common" {
  name        = var.common_share
  description = "GLAMacles shared training data"
  share_proto = "CEPHFS"
  share_type  = var.share_type
  size        = var.common_size_gb

  # Guard the school's dataset: Terraform will REFUSE to delete this share
  # (accidental config edit, stray `terraform destroy`, etc.). To intentionally
  # tear it down, comment this out first, then apply/destroy.
  lifecycle {
    prevent_destroy = true
  }
}

resource "openstack_sharedfilesystem_share_access_v2" "common_ro" {
  share_id     = openstack_sharedfilesystem_share_v2.common.id
  access_type  = "cephx"
  access_to    = var.common_ro_rule
  access_level = "ro"
}

# Read-write rule for you to load data into the common share (see README).
resource "openstack_sharedfilesystem_share_access_v2" "common_rw" {
  share_id     = openstack_sharedfilesystem_share_v2.common.id
  access_type  = "cephx"
  access_to    = var.common_rw_rule
  access_level = "rw"
}

# ---- Per-instructor scratch shares (read-write) ----------------------------
# One per instructor, shared by all of that instructor's VMs.
resource "openstack_sharedfilesystem_share_v2" "scratch" {
  for_each    = var.instructors
  name        = "glamacles-scratch-${each.key}"
  description = "GLAMacles scratch for ${each.key}"
  share_proto = "CEPHFS"
  share_type  = var.share_type
  size        = var.scratch_size_gb

  # Once your instructor roster is final, uncomment to protect project scratch
  # data too. Leave it OFF while iterating on the instructor list, since
  # removing/renaming an instructor would otherwise make `apply` error instead
  # of cleanly dropping that scratch share.
  # lifecycle {
  #   prevent_destroy = true
  # }
}

resource "openstack_sharedfilesystem_share_access_v2" "scratch" {
  for_each     = var.instructors
  share_id     = openstack_sharedfilesystem_share_v2.scratch[each.key].id
  access_type  = "cephx"
  access_to    = "glamacles-scratch-${each.key}-rw"
  access_level = "rw"
}
