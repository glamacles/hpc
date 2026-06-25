# GLAMacles — Jetstream2 project VMs

Terraform provisioning for a glaciology + ML summer school. One GPU VM per
instructor (shared by the instructor + 3–4 students), a shared dataset volume for
the whole school, and reliable `apply`/`destroy`.

We provision **directly against the OpenStack API** with Terraform rather than
through CACAO — CACAO instance provisioning proved unreliable. Terraform is not
an orchestration service like CACAO; it just calls the same API from your laptop,
deterministically, and tracks what it created in a state file.

## Where things are

- **[terraform/](terraform/)** — the deployment. Start at
  [terraform/README.md](terraform/README.md). This is the only active path.
- **[docs/instructor-guide.md](docs/instructor-guide.md)** — hand to instructors.
- **[docs/student-guide.md](docs/student-guide.md)** — hand to students (login,
  GPU kernel, data folders, etiquette).
- **[TESTING.md](TESTING.md)** — provision one VM and emulate the
  instructor/student experience end to end.
- **[keys/](keys/)** — drop instructor SSH public keys here (`<username>.pub`).
- **[clouds.yaml.example](clouds.yaml.example)** — auth template.
- **[archive/](archive/)** — the original bash + OpenStack-CLI implementation,
  retired in favor of Terraform. Reference only; do not run.

## What you get per VM

| Piece | Detail |
|---|---|
| Flavor | `g3.large` — 16 vCPU, 60 GB RAM, **50% A100 (20 GB VRAM)**, 32 SU/hr |
| Image | `Featured-Ubuntu24` (NVIDIA vGPU driver preinstalled) |
| Access | **The Littlest JupyterHub** — per-student logins, instructor is admin |
| Default env | `/opt/glamacles/venv` (uv-managed): PyTorch (cu124) + JAX (cuda12) + the usual scientific stack, exposed as the Jupyter kernel **"GLAMacles (PyTorch+JAX GPU)"** |
| Tools | `git`, `uv` (system-wide), shell via SSH (`ubuntu`) or the JupyterLab terminal |
| Storage | `/data/common` (school-wide shared dataset) and `/data/scratch` (per-instructor) — both **read-write** (world-writable, sticky bit) Manila CephFS shares |

`g3.xl` (full A100) is intentionally **not** used: those instances are rarely
available on JS2. To give an instructor more GPU, run **two** `g3.large` for them
(`vms = 2`) rather than waiting on an `xl`.

## Deploy (short version)

Full steps — including OpenStack auth and the one-time cleanup — are in
[terraform/README.md](terraform/README.md).

```bash
cd terraform
export OS_CLIENT_CONFIG_FILE="$PWD/../clouds.yaml"
terraform init && terraform validate
terraform plan && terraform apply
terraform output vms      # name -> ip, JupyterHub URL, ssh command
```

The config is keyed by instructor in `terraform/terraform.tfvars`:

```hcl
instructors = {
  rachel = {}                                 # 1 VM
  diego  = { vms = 2 }                         # 2 VMs, sharing one scratch share
  mei    = { requirements = "reqs/mei.txt" }   # 1 VM + extra pip packages
}
```

Each instructor gets `glamacles-<name>` VM(s), a `glamacles-scratch-<name>` share,
and `keys/<name>.pub` injected for SSH. After `apply`, a VM takes ~8–15 min to
finish its cloud-init build (venv + PyTorch/JAX + TLJH); it's done when
`ssh ubuntu@<ip> 'cloud-init status --wait'` returns `done`.

## How many VMs per instructor?

Your allocation may fit more than six VMs, so an instructor can have two
(`vms = 2`).

- **1 VM (default, recommended to start).** TLJH already isolates the 3–4 students
  into separate accounts/home dirs, so the *only* thing a second VM buys is **more
  GPU** — the 20 GB of VRAM is shared by everyone on the box. If students mostly
  iterate on small models or take turns training, one VM is plenty.
- **2 VMs.** Both share that instructor's read-write scratch share (so team
  data/checkpoints are common), each with its own 20 GB GPU slice. Split students
  ~2 per VM to roughly halve GPU contention. Costs: 2× the SU burn, two hub URLs,
  and home directories are local to each VM (a student should pick one VM; shared
  work goes in scratch).

**Recommendation:** start most instructors at 1 and watch week-1 contention
(`nvidia-smi`, OOM reports), then set `vms = 2` for the heaviest. Decide up front
where you can — raising `vms` later replaces that instructor's VM (see
terraform/README "Scaling").

## Controlling SU burn

`g3.large` is 32 SU/hr. Rough planning numbers:

| Scenario | SU/day | SU / 2-week school |
|---|---|---|
| 6 VMs, 24/7 | 4,608 | ~64,500 |
| 6 VMs, shelved nights/weekends (~10 h/day) | 1,920 | ~27,000 |
| 12 VMs (2/instructor), 24/7 | 9,216 | ~129,000 |

Check your balance with `openstack --os-cloud openstack limits show --absolute`.
Terraform doesn't shelve; to pause charges overnight without destroying state,
shelve the instances (they're normal servers) and unshelve in the morning — see
terraform/README "Controlling SU burn".

## Loading the shared dataset

`/data/common` is mounted **read-write** on every VM, so you can load data the
easy way: SSH into any VM (or use the JupyterLab uploader) and copy files into
`/data/common`. All VMs see it immediately.

For a bulk upload from your laptop without going through a VM, mount the share
directly using the RW rule:

```bash
cd terraform
terraform output common_export_path
terraform output -raw common_rw_access_key
```

Both `/data/common` and `/data/scratch` are world-writable with a sticky bit
(like `/tmp`): everyone can add files, but no one can delete/rename files they
don't own — so a student can't wipe the curated dataset (its files are owned by
whoever loaded them). Keep the dataset files non-world-writable (default umask is
fine) and they're safe from modification too.

## Security notes

- The security group opens 22/80/443 to the world. Set `enable_https = true`
  (Cloudflare DNS + Let's Encrypt — see [terraform/README.md](terraform/README.md)
  "HTTPS") so JupyterHub is served over TLS and logins are encrypted. With HTTPS
  off, the hub is plain HTTP and passwords cross the wire in the clear — only
  acceptable as a short-lived test.
- TLJH's default authenticator lets a user set their password on first login. For
  a class, consider admin approval or restricting usernames after the instructor
  account is created, and tighten the security group's `remote_ip_prefix` to
  campus ranges if you can ([terraform/network.tf](terraform/network.tf)).

## Assumptions to confirm against your allocation

Baked into the Terraform variables from the JS2 docs; `terraform plan` and a
quick Horizon check will confirm:

- External network is named **`public`**, region **`IU`**, clouds.yaml cloud name
  **`openstack`**.
- Share type is **`cephfsnativetype`**.
- `Featured-Ubuntu24` is the current GPU featured image (`openstack --os-cloud
  openstack image list | grep -i featured`).
- TLJH supports Ubuntu 24.04; if its bootstrap ever fails there, set `image` to
  `Featured-Ubuntu22` in `terraform.tfvars`.
