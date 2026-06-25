# SSH keys

How SSH access is granted to each VM:

1. **Admin key** — `admin_pubkey` in `terraform/variables.tf` (default
   `~/.ssh/id_ed25519.pub`), registered as the `glamacles-admin` OpenStack keypair
   and injected as the `ubuntu` user on every VM. That's your break-glass access.

2. **Per-instructor key** — drop each instructor's *public* key here as
   `keys/<instructor-username>.pub`, matching the instructor key in
   `terraform.tfvars` (e.g. `keys/rachel.pub`). `terraform apply` injects it into
   that instructor's VM(s) via cloud-init, so they can `ssh ubuntu@<ip>`.

3. **Shared keys** — anything in `keys/shared/*.pub` is added to *every* VM
   (e.g. a co-organizer or a TA who roams across projects).

`.pub` files only — never put private keys in this repo.

## How an instructor creates their credentials (send this to them)

On their own laptop:

```bash
ssh-keygen -t ed25519 -C "rachel@glamacles" -f ~/.ssh/glamacles
#   -> Enter passphrase: <yes, set one>      (see "Passphrases" below)
```

This makes two files:
- `~/.ssh/glamacles`      → **private** key, stays on their laptop, never shared
- `~/.ssh/glamacles.pub`  → **public** key, they send to you (paste in email/Slack)

You save it as `keys/rachel.pub`. They connect with:

```bash
ssh -i ~/.ssh/glamacles ubuntu@<vm-floating-ip>
```

(or add a `Host` block to `~/.ssh/config` so they can just type `ssh glamacles-rachel`).

## Passphrases — yes, use them

A passphrase encrypts the **private key file on the laptop**. It's never sent to
the server, so it works regardless of how the VM is configured — the server only
ever sees the public key. If the laptop is lost, the passphrase buys time before
the key can be used. To avoid retyping it every connection, load it into the
agent once per session:

```bash
ssh-add ~/.ssh/glamacles      # prompts for the passphrase once
ssh ubuntu@<vm-floating-ip>   # no prompt after that
```

Students generally don't need SSH — they use JupyterHub in the browser and get a
terminal inside JupyterLab. If one does, same flow: they generate a key, you add
it (e.g. to `keys/shared/` or the relevant instructor's VM).
