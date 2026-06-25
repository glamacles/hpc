# GLAMacles — Instructor Guide

You have a dedicated GPU VM on Jetstream2 for your project, shared by you and your
3–4 students through JupyterHub. This guide covers what's on the machine, how to
manage students, and how to install/maintain software.

## 1. What's on the VM

- **GPU**: an NVIDIA A100 slice — ~20 GB of GPU memory, shared by everyone logged
  into this VM.
- **Access for students**: JupyterHub (The Littlest JupyterHub / TLJH) at
  `https://<your-project>.glamacles.geoml.net/` (served over HTTPS with a
  Let's Encrypt cert). Each student gets an isolated account and home directory.
- **Shared Python env**: `/opt/glamacles/venv`, exposed as the Jupyter kernel
  **"GLAMacles (PyTorch+JAX GPU)"** — PyTorch (CUDA 12.4), JAX (CUDA 12), and the
  usual scientific stack. This is the env you manage for the class.
- **Tools**: `git`, `uv` (a fast pip/venv replacement), system Python 3.
- **Shared storage** (also visible in JupyterLab as `~/common` and `~/scratch`):
  - `/data/common` — **read-write**, common datasets for the whole school
    (everyone can upload; a sticky bit stops anyone deleting files they don't own).
  - `/data/scratch` — **read-write**, shared by your project (good for
    checkpoints, generated data, anything the team passes around).

## 2. Your access (two ways in)

You are a **JupyterHub admin**, which on TLJH also grants you **passwordless
`sudo`** on the VM. So you have two equivalent ways to administer it:

1. **JupyterLab terminal** — open a Terminal from the Launcher and use `sudo`
   directly. No SSH needed for most tasks.
2. **SSH** — `ssh ubuntu@<vm-ip>` using the key you gave the organizers. Handy
   for longer sessions or copying files.

> After the VM is rebuilt, SSH may warn that the host key changed — that's
> expected; run `ssh-keygen -R <vm-ip>` and reconnect.

### Adding your own SSH key (self-service)

If the organizers didn't pre-load your key, you can authorize your own from the
JupyterLab terminal (you have sudo). On your **laptop**, get your *public* key
(create one with `ssh-keygen -t ed25519` if you don't have it):

```bash
cat ~/.ssh/id_ed25519.pub      # the single line starting "ssh-ed25519 ..."
```

Then in the **JupyterLab terminal** on your VM, append it to the `ubuntu` account
(paste your real key in the quotes — the *public* one, never the private key):

```bash
echo 'ssh-ed25519 AAAA...your-key you@laptop' | sudo tee -a /home/ubuntu/.ssh/authorized_keys >/dev/null
```

Now `ssh ubuntu@<vm-ip>` from your laptop works.

> **Caveat:** a key added this way lives on the VM's local disk, so it's **lost
> if the VM is rebuilt**. For access that survives rebuilds, send your public key
> to the organizers to bake into the VM (`keys/<username>.pub`). Self-service is
> perfect for "I need a shell right now"; the baked key is the durable option.

## 3. Managing students

1. Log in to `https://<your-project>.glamacles.geoml.net/` with your instructor
   username — **your first login sets your password**, and your account is admin.
2. Open **Control Panel → Admin** (top of JupyterLab).
3. **Add users**: enter each student's username. Share the URL with them; their
   **first login sets their own password**.
4. From the Admin panel you can also stop a user's server, access a user's
   notebooks, or remove a user.

Hand students the **Student Guide** (`student-guide.md`) — it covers login, the
GPU kernel, the data folders, and etiquette.

## 4. Installing software

### Into the shared env (everyone gets it) — the common case

From a JupyterLab terminal or over SSH:

```bash
sudo uv pip install --python /opt/glamacles/venv <package>
```

The package is immediately available in the "GLAMacles (PyTorch+JAX GPU)" kernel
for all students (they may need to restart their kernel). Examples:

```bash
sudo uv pip install --python /opt/glamacles/venv segmentation-models-pytorch
sudo uv pip install --python /opt/glamacles/venv "xarray[complete]" rioxarray
```

> **Don't upgrade JAX.** It's pinned to `jax==0.4.38` on purpose: newer jaxlib
> requires CUDA Virtual Memory Management, which this GPU (an A100 vGPU slice)
> does not support, so a `jax` upgrade breaks the GPU kernel with
> "Device 0 does not support CUDA Virtual Memory Management". PyTorch is
> unaffected and can be upgraded normally.

### System packages

```bash
sudo apt-get update && sudo apt-get install -y <package>
```

### When a student needs something custom

Point them at §6 of the Student Guide (personal `uv venv` + their own kernel).
That keeps your shared env stable — students can't write to it, by design, so one
student can't break everyone's environment.

## 5. Data management

- **`/data/common` is read-write for everyone** (world-writable, sticky bit). The
  organizers load the main shared datasets, but you and your students can upload
  to it too — including via the JupyterLab file uploader. Etiquette: don't modify
  or delete the curated datasets; the sticky bit prevents deleting files you don't
  own, but treat common as shared space and keep day-to-day work in scratch.
- **`/data/scratch` is your project's read-write space** (world-writable with a
  sticky bit, like `/tmp`, so any team member can add files but not delete
  others'). Encourage students to namespace their work, e.g.
  `scratch/<student>/...`.
- Students see these as `~/common` and `~/scratch` in JupyterLab. If a student
  doesn't see them, their home was created before the links existed — fix with:
  ```bash
  sudo ln -sfn /data/common  /home/jupyter-<user>/common
  sudo ln -sfn /data/scratch /home/jupyter-<user>/scratch
  sudo chown -h jupyter-<user>:jupyter-<user> /home/jupyter-<user>/common /home/jupyter-<user>/scratch
  ```

### Uploading a dataset

- **Small files:** the JupyterLab upload button works fine.
- **Large datasets (tens of GB, many files):** don't use the browser uploader —
  open a JupyterLab **Terminal** (or SSH) and pull data server-side. Put it in a
  **named subfolder** so six projects' data doesn't pile up loose in the share
  root:
  ```bash
  mkdir -p /data/common/<your-project>
  cd /data/common/<your-project>
  wget https://example.org/dataset.tar.gz && tar xzf dataset.tar.gz
  # or: rsync -av you@host:/path/to/data/ /data/common/<your-project>/
  ```
- A dataset you upload is owned by your account and, thanks to the sticky bit +
  default `644` perms, students can read it but can't delete or modify it — so
  there's no need to be root. (If you want a dataset truly locked, `chmod -R a-w`
  it after upload.)

### Where things should live

| What | Where |
|---|---|
| Shared input datasets (whole project/school) | `/data/common/<project>/` |
| Checkpoints, model weights, logs, generated data | `/data/scratch/<student-or-topic>/` |
| Code | git (students push from the JupyterLab terminal) |
| The shared GPU env | `/opt/glamacles/venv` (instructor-managed, §4) |

Anything in a student's home or on the VM's local disk is **not** backed up and is
lost if the VM is rebuilt — steer durable data into `/data/...` and code into git.

## 6. Monitoring the GPU

The whole VM shares one ~20 GB GPU, so contention is the thing to watch:

```bash
nvidia-smi                 # snapshot: who's using GPU memory and compute
watch -n 5 nvidia-smi      # live view
```

If students hit out-of-memory errors, it's usually several kernels each holding
memory. GPU memory is released when a kernel is **restarted/stopped**, so ask
people to restart idle kernels (you can also stop a user's server from the Admin
panel). The JAX kernel is configured **not** to pre-grab all GPU memory, so JAX
and PyTorch can share more gracefully.

If contention is a persistent problem for your project, tell the organizers — a
second VM can be added for your project to spread students across two GPUs.

## 7. Maintaining JupyterHub

```bash
sudo systemctl status jupyterhub      # is the hub running?
sudo systemctl restart jupyterhub     # restart it
sudo tljh-config show                 # current hub config
sudo journalctl -u jupyterhub -e      # hub logs (auth issues, spawn failures)
```

Per-user notebook server logs live under each user's session; a failed kernel is
usually a package/import problem in the shared env — reproduce it in a terminal
with `/opt/glamacles/venv/bin/python -c "import <thing>"`.

## 8. Good to know

- **Persistence**: home directories and `/data/scratch` persist while the VM
  runs. The VM itself is reproducible from the organizers' Terraform config, so
  treat code as belonging in git, not only on the VM.
- **Cost**: the VM bills compute hours while running. The organizers may
  **shelve** (pause) VMs overnight/weekends to save the allocation — if the URL
  is unreachable in the morning, it may just need un-shelving; ping them.
- **Security**: JupyterHub is served over HTTPS (Let's Encrypt), so logins are
  encrypted in transit. Still good practice for students to use a unique password
  they don't reuse elsewhere.
