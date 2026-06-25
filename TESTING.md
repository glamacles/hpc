# Test drive: provision one VM and emulate the instructor + student experience

This walks through a **single-VM** test so you can validate the whole pipeline
cheaply before launching all six. Budget ~20–30 min, most of it waiting on the
cloud-init build. A single g3.large costs 32 SU/hr; shelve or tear down when done.

Provisioning is via Terraform — see [terraform/README.md](terraform/README.md)
for the full reference; this is the condensed test path.

---

## Part 0 — Authenticate to OpenStack

Terraform (and the `openstack` CLI, handy for spot checks) read a `clouds.yaml`.

1. Go to <https://js2.jetstream-cloud.org>, log in with ACCESS-CI.
2. Top-left: select your allocation (project).
3. Sidebar: **Identity → Application Credentials → Create Application Credential**.
   Name it, set an **expiry past the end of the school**, create it.
4. Click **Download openrc/clouds.yaml** (the clouds.yaml button), or paste the
   ID/secret into a copy of [clouds.yaml.example](clouds.yaml.example).
5. Note the **cloud name** in the file — JS2's default is `openstack` (matches
   `os_cloud` in `terraform.tfvars`).

Point Terraform at the file and verify auth:

```bash
export OS_CLIENT_CONFIG_FILE="$PWD/clouds.yaml"      # if it's in the repo root
openstack --os-cloud openstack token issue            # should return a token
openstack --os-cloud openstack image list | grep -i featured   # confirm image name
```

---

## Part 1 — Your admin SSH key

```bash
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519   # set a passphrase if you like
```

This is the key injected as `ubuntu` on every VM (`admin_pubkey` in
`terraform/variables.tf`, default `~/.ssh/id_ed25519.pub`). To also test
instructor-key injection, drop a public key at `keys/<instructor>.pub` — for the
test you can reuse your own: `cp ~/.ssh/id_ed25519.pub keys/jake.pub`.

---

## Part 2 — Configure one small VM

`terraform/terraform.tfvars` ships set up for exactly this — one instructor, no
extras, small shares:

```hcl
instructors = {
  jake = {}
}
common_size_gb  = 20
scratch_size_gb = 50
```

Leave flavor/image at their defaults.

---

## Part 3 — Provision

```bash
cd terraform
export OS_CLIENT_CONFIG_FILE="$PWD/../clouds.yaml"
terraform init           # first time only — downloads the OpenStack provider
terraform validate
terraform plan           # review (~12 resources for one VM)
terraform apply          # type 'yes'
terraform output vms     # name -> ip, JupyterHub URL, ssh command
```

The VM boots in ~1 min but the **cloud-init build runs another ~8–15 min**
(mounts, uv, PyTorch+JAX, TLJH). Wait for it:

```bash
ssh ubuntu@<ip> 'cloud-init status --wait'   # blocks until done (or reports error)
# or watch it: ssh ubuntu@<ip> 'tail -f /var/log/cloud-init-output.log'
```

If `ssh` is refused at first, the VM is still booting — wait a minute. After a VM
rebuild on a recycled IP you'll get a host-key-changed warning; clear it with
`ssh-keygen -R <ip>`. If the build ever fails on TLJH under Ubuntu 24.04, set
`image = "Featured-Ubuntu22"` in `terraform.tfvars` and re-apply.

---

## Part 4 — Emulate the INSTRUCTOR experience

Instructors customize software (terminal or SSH) and run the class hub.

**A. SSH in and check the GPU + shares:**

```bash
ssh ubuntu@<ip>
cat /etc/glamacles-welcome          # orientation printed on login too
nvidia-smi                          # should show ~20 GB A100 slice
/opt/glamacles/venv/bin/python -c "import torch; print('torch cuda:', torch.cuda.is_available())"
/opt/glamacles/venv/bin/python -c "import jax; print('jax devices:', jax.devices())"
ls /data/common /data/scratch       # both shares mounted
touch /data/scratch/hello /data/common/hello && echo "both shares are writable"
```

**B. Add a package to the shared env** (shows up for all their students):

```bash
sudo uv pip install --python /opt/glamacles/venv segmentation-models-pytorch
```

(Instructors can also do this from the JupyterLab terminal — TLJH admins get
passwordless sudo, so SSH isn't strictly required.)

**C. Run the JupyterHub as admin:** open `http://<ip>/` in a browser. Log in with
username `jake` (the instructor name) and **any password — the first login sets
it**, and because `jake` is the TLJH admin, that account can manage users. Open
**Control Panel → Admin** to add student usernames.

---

## Part 5 — Emulate the STUDENT experience

1. Open `http://<ip>/` (incognito window so you're not reusing the admin session).
2. Log in as a student username the instructor added (first login sets that
   student's password). Each student gets their own isolated home directory.
3. JupyterLab opens. In the Launcher, pick the **"GLAMacles (PyTorch+JAX GPU)"**
   kernel (not the default Python 3).
4. In a notebook cell:

   ```python
   import torch
   torch.cuda.is_available(), torch.cuda.get_device_name(0)

   x = torch.randn(4096, 4096, device="cuda")
   (x @ x).sum()        # runs on the GPU

   import os
   os.listdir("common")           # shared dataset (symlinked into home, read-write)
   open("scratch/student-test.txt", "w").write("hi from a notebook")  # read-write
   ```

5. Open a **Terminal** from the Launcher — students get a shell here too, with
   `git` and `uv` available, without needing SSH.

Things to notice while emulating:
- All students share the **one 20 GB GPU**. Open two notebooks both allocating
  big tensors to feel the contention — this is the signal for whether an
  instructor needs a second VM (`vms = 2`).
- Home dirs are per-student and per-VM; shared team data lives in `scratch/`.
- `common/` and `scratch/` appear in the file browser via symlinks in each home.

---

## Part 6 — Clean up the test

```bash
cd terraform
terraform destroy          # delete the test VM, shares, network, keypair, IPs
```

To pause SU charges instead of destroying (keeps state intact):

```bash
openstack --os-cloud openstack server shelve glamacles-jake     # ...unshelve later
```

When the test passes, expand `terraform.tfvars` to the six real instructors and
`terraform apply` for the live deployment.
```
