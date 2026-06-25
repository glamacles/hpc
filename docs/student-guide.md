# GLAMacles — Student Guide

Welcome! Your project has a GPU virtual machine on Jetstream2 that you'll use
through **JupyterHub** in your web browser. This guide covers logging in, running
GPU code, where to put data, and how to install extra packages.

## 1. Logging in

1. In a browser, go to the address your instructor gives you — a secure web
   address like **`https://<your-project>.glamacles.geoml.net/`**
2. Enter a username (pick one and remember it) and a password.
   - **The first time you log in, the password you type becomes your password.**
     Choose something only you know.
3. You land in **JupyterLab**. You have your own private home directory; other
   students can't see your files there.

## 2. The JupyterLab interface

- **Launcher** (the "+" tab): start notebooks, a terminal, or a text editor.
- **File browser** (left sidebar): your home directory, plus two shared folders
  (see §4).
- **Terminal**: a normal Linux shell on the VM — `git`, `python`, and `uv` are
  available. No password/SSH needed; you're already on the machine.

## 3. Running GPU code (the right kernel)

When you open a notebook, pick the kernel named:

> **GLAMacles (PyTorch+JAX GPU)**

(Not the plain "Python 3" kernel — that one has no GPU libraries.) This kernel
has PyTorch, JAX, NumPy/SciPy/pandas, scikit-learn, xarray, and more, all set up
to use the GPU.

Verify the GPU works:

```python
import torch
print(torch.cuda.is_available())          # True
print(torch.cuda.get_device_name(0))      # an NVIDIA A100 ...

import jax
print(jax.devices())                       # [CudaDevice(id=0)]
```

## 4. Where your files go

You have three places, with different rules:

| Folder | In file browser | Rule | Use for |
|---|---|---|---|
| Home (`~`) | top level | private to you | your notebooks, code |
| `common/` | `~/common` | **shared, read-write** (whole school) | the common datasets — you can upload here, but don't modify/clutter the provided data |
| `scratch/` | `~/scratch` | read-write, shared with your whole project | datasets you generate, checkpoints, outputs the team shares |

- **`common/` is the whole school's shared space** — you *can* upload here, but
  don't modify or delete the provided datasets, and keep your own work out of it.
  Put your outputs in `scratch/` or your home instead. (You can't delete files
  other people own, but please don't clutter the common area.)
- `scratch/` is shared by everyone on your project, so name your files/folders
  clearly (e.g. `scratch/yourname/...`).
- Keep your real code in **git** (push to GitHub/GitLab). Treat the VM as
  replaceable — see §7.

### Getting data on and off the VM

- **Small files** (a notebook, a few MB): drag them into the file browser, or use
  the upload (↑) button. To download, right-click a file → **Download**.
- **Large datasets / many files / folders:** don't use the browser uploader (it's
  slow and can stall). Open a **Terminal** (Launcher → Terminal) and pull the data
  straight onto the VM:
  ```bash
  cd ~/scratch
  wget https://example.org/dataset.tar.gz      # download from a URL
  tar xzf dataset.tar.gz
  # or copy from another machine you can reach:
  rsync -av you@host:/path/to/data/ ~/scratch/yourname/data/
  ```
  This streams server-side (fast), instead of going laptop → browser → VM.

### Where to put what

| What | Where | Why |
|---|---|---|
| Notebooks, code | your home + **git** | private; git is the real backup |
| Checkpoints, model weights, logs, generated data | `~/scratch/yourname/...` | read-write, shared with your team, survives kernel restarts |
| The provided shared datasets | read from `~/common/...` | already on fast shared storage — read in place, don't copy into scratch |
| Anything you must keep after the school | copy **off** the VM | the VM is temporary (see §7) |

## 5. The GPU is shared — be a good neighbor

Everyone on this VM shares **one GPU with ~20 GB of memory**. A few habits keep
it usable for the whole team:

- **Restart your kernel when you're done** with a heavy job (Kernel → Restart).
  GPU memory isn't freed until the kernel that allocated it stops.
- If you get a CUDA **out-of-memory** error, it's usually because other notebooks
  (yours or teammates') are holding memory. Restart idle kernels and shrink your
  batch size.
- Check what's using the GPU from a terminal: `nvidia-smi`.
- Coordinate with teammates before launching a long training run.

## 6. Installing extra packages

- **First, ask your instructor.** They can add a package to the shared kernel so
  everyone gets it — usually the quickest path.
- **Need something just for yourself, or a different version?** Make your own
  environment and register it as a personal kernel:

  ```bash
  # in a terminal
  uv venv ~/myenv
  uv pip install --python ~/myenv ipykernel <packages-you-need>
  ~/myenv/bin/python -m ipykernel install --user --name myenv --display-name "My env"
  ```

  Refresh JupyterLab and pick **"My env"** as your notebook kernel. Note: if you
  need GPU PyTorch/JAX in your personal env, install them there too, e.g.
  `uv pip install --python ~/myenv torch --torch-backend=cu124 "jax[cuda12]"`.

## 7. Saving your work / persistence

- Your home directory and `scratch/` **persist** while the VM is running, and
  across normal restarts.
- The VM can be rebuilt by the organizers (for fixes or at the school's end), so
  **don't rely on it as permanent storage**: push code to git, and copy anything
  you need to keep off the VM before the school ends.

## 8. Quick troubleshooting

| Symptom | Try |
|---|---|
| Kernel won't start / dies immediately | Kernel → Restart; if it persists, tell your instructor |
| `CUDA out of memory` | Restart idle kernels, reduce batch size, `nvidia-smi` to see usage |
| "Permission denied" saving a file | Likely a file owned by someone else — save your own work to `scratch/` or home |
| Can't see `common/` or `scratch/` | Tell your instructor (the symlinks may need adding to your home) |
| Page won't load at your `https://...` address | Check the address; ask if the VM is shelved/off |
