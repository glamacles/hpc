# GLAMacles on Terraform

The deployment: GPU VMs + TLJH + Manila shares, with a state file so
`plan`/`apply`/`destroy` are reliable and idempotent.

Terraform talks straight to the OpenStack API from your laptop — it is **not** an
orchestration service like CACAO, so it doesn't reintroduce the reliability
problems that prompted the switch. (An earlier bash + OpenStack-CLI version lives
in [../archive/](../archive/), retired in favor of this.)

## Files

```
versions.tf      provider + clouds.yaml auth
variables.tf     all knobs
terraform.tfvars YOUR values — edit this
network.tf       keypair, security group, network/subnet/router
shares.tf        common + per-instructor scratch CephFS shares (all read-write)
compute.tf       VMs + floating IPs (renders cloud-init/*.tftpl)
dns.tf           Cloudflare DNS records (only when enable_https = true)
outputs.tf       inventory + data-upload credentials
shelve.sh        shelve/unshelve all VMs (control SU burn)
reqs/            optional per-instructor pip requirements files
cloud-init/instructor-vm.yaml.tftpl   per-VM build recipe
```

SSH keys are read from the repo's `../keys/` (`<instructor>.pub` + `shared/*.pub`).

## Install Terraform

```bash
# one option of many — see https://developer.hashicorp.com/terraform/install
sudo snap install terraform --classic    # or: brew install terraform
# OpenTofu (open-source drop-in) also works: replace `terraform` with `tofu`.
```

You also need the Manila client behavior server-side only — no extra local
install beyond the OpenStack provider, which `terraform init` fetches.

## If resources with these names already exist

Terraform creates the keypair, security group, and network itself. The keypair
name is the one that hard-collides if it already exists (e.g. left over from the
archived bash scripts or a prior attempt) — delete it first:

```bash
openstack --os-cloud openstack keypair delete glamacles-admin
openstack --os-cloud openstack security group delete glamacles-sg   # if it exists
```

Any leftover `glamacles-net`/`glamacles-router` are easiest to remove in Horizon
(detach the router interface, then delete router → network). Alternatively
`terraform import` existing resources instead of deleting.

## Deploy

```bash
cd terraform
# auth: same clouds.yaml as the CLI. Point Terraform at it if it's not in a
# default search path:
export OS_CLIENT_CONFIG_FILE="$PWD/../clouds.yaml"

terraform init        # downloads the OpenStack provider
terraform validate    # sanity-check the config
terraform plan        # review what will be created
terraform apply       # type 'yes'
terraform output vms  # name -> ip, JupyterHub URL, ssh command
```

VMs boot in ~1 min; the cloud-init build (uv + PyTorch/JAX + TLJH) takes another
~8–15 min. Track it:

```bash
ssh ubuntu@<ip> 'tail -f /var/log/cloud-init-output.log'   # done at /opt/glamacles/SETUP_DONE
```

Then see the repo-root **TESTING.md** for the instructor/student walkthrough —
it's identical from here (browse to the URL, log in as the instructor, add
students, pick the "GLAMacles (PyTorch+JAX GPU)" kernel).

## Loading the shared dataset

`/data/common` is mounted **read-write** on every VM, so the easy path is to SSH
into any VM (or use the JupyterLab uploader) and copy files into `/data/common`.

For a bulk upload straight from your laptop, mount the share directly with the RW
rule:

```bash
terraform output common_export_path
terraform output -raw common_rw_access_key
```

Use those with the same keyring + fstab pattern as the cloud-init (rule name
`glamacles-common-rw`) on any JS2 VM, copy data in, then unmount.

## Scaling / changing the deployment

The deployment is keyed by **instructor username** in the `instructors` map:

```hcl
instructors = {
  rachel = {}                                 # 1 VM
  diego  = { vms = 2 }                         # 2 VMs, sharing one scratch share
  mei    = { requirements = "reqs/mei.txt" }   # 1 VM + extra pip packages
}
```

Each instructor gets `glamacles-<name>` VM(s), a `glamacles-scratch-<name>` share,
and their `keys/<name>.pub` injected for SSH. Edit `terraform.tfvars` and re-run
`terraform apply`; Terraform only changes the delta:

- **Add an instructor** → creates their VM(s) + scratch share.
- **`vms = 2`** → two VMs for that instructor, sharing one scratch share and the
  same requirements. Note: raising `vms` from 1→2 **renames** the node key
  (`rachel` → `rachel-1`), so Terraform replaces the single VM with two — fine
  before the school starts, disruptive once students have data on it. Set the
  count up front where you can.
- **`requirements = "reqs/<name>.txt"`** → extra pip packages installed into the
  shared venv on all of that instructor's VMs. See `reqs/README.md`. Changing the
  file later re-applies (rebuilds those VMs, since user-data changes force
  replacement).

## Controlling SU burn

Terraform doesn't shelve. To pause charges overnight without destroying state,
shelve the VMs (they're normal servers) with the helper:

```bash
./shelve.sh shelve      # stop SU accrual (preserves disk, floating IP, state)
./shelve.sh unshelve    # bring them back (a few min; /data re-mounts)
./shelve.sh status      # power state of each VM
```

It acts on every `glamacles-*` server and is independent of Terraform state —
`terraform plan` won't try to "fix" a shelved VM. Needs the same OpenStack auth
as Terraform (`OS_CLIENT_CONFIG_FILE`, or a sourced openrc).

## HTTPS (optional, via Cloudflare)

Off by default (deployments serve JupyterHub over plain HTTP). To enable real
certs — each VM gets `<node>.<dns_base>.<dns_zone>` with a Let's Encrypt cert:

1. **Cloudflare API token** with `Zone:DNS:Edit` + `Zone:Read` on your zone
   (Cloudflare dashboard → My Profile → API Tokens). Store it so it persists
   across shells and applies — copy `secret.auto.tfvars.example` to
   `secret.auto.tfvars` (gitignored) and paste the token there:
   ```bash
   cp secret.auto.tfvars.example secret.auto.tfvars   # then edit it
   ```
   Terraform auto-loads `*.auto.tfvars` every run. (Alternatively `export
   CLOUDFLARE_API_TOKEN=...`, but that only lasts for the current shell.) Either
   way, keep a copy in a password manager — Cloudflare shows the token only once.
2. **Set the variables** in `terraform.tfvars`:
   ```hcl
   enable_https      = true
   dns_zone          = "example.org"     # your Cloudflare zone
   dns_base          = "glamacles"       # rachel.glamacles.example.org ("" => rachel.example.org)
   letsencrypt_email = "you@umontana.edu"
   ```
3. `terraform apply`. It creates a DNS A record per VM (DNS-only / grey cloud)
   pointing at the floating IP, and each VM's TLJH enables Let's Encrypt for its
   hostname at boot. `terraform output vms` then shows `https://...` URLs.

Notes:
- Cert issuance needs the DNS record live and ports 80/443 open (both already
  are). Traefik retries until DNS propagates, so a cert may take a couple of
  minutes after `apply`; check `sudo tljh-config show` / the proxy logs on a VM.
- Records are **not proxied** (grey cloud) on purpose — Cloudflare proxying would
  break the HTTP-01 challenge and JupyterHub websockets.
- Turning HTTPS on/off changes VM user-data, so it **rebuilds the VMs**. Decide
  before the school, or before students have data on them.
- HTTP stays reachable on the IP too; if you want to force HTTPS-only, lock port
  80 down after certs issue (it's needed for issuance/renewal, so leave it open).

## Data safety

Shares persist across `apply` and are **not** touched by VM rebuilds — a new VM
just re-mounts the same shares, so `/data/common` and `/data/scratch` data
survives. A share is only destroyed if you remove/rename its instructor in
`terraform.tfvars` (drops that scratch share), change its `share_type`/proto, or
`terraform destroy`.

The common share has `prevent_destroy = true` (in `shares.tf`), so Terraform
**refuses** to delete it — protecting the school's dataset from an accidental
edit or stray destroy. Always scan `terraform plan` for `must be replaced` /
`destroy` on any `..._share_v2` before applying.

## Teardown

```bash
terraform destroy          # deletes VMs, floating IPs, shares, network, keypair
```

It removes exactly what it created, in order, with no orphaned floating IPs.
**Because of the guard, `destroy` will error on the common share** — comment out
its `lifecycle { prevent_destroy = true }` block in `shares.tf` first if you
really mean to delete the dataset.

## State file — keep it safe

`terraform.tfstate` records all resources **and contains the cephx access keys**
(marked sensitive but stored in plaintext in state). Don't share it or commit it
to a public repo; back it up somewhere private if you care about clean teardown.
