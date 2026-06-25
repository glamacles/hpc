# Per-instructor requirements files

Drop an instructor's extra pip packages here as a normal `requirements.txt`,
then point their entry in `terraform.tfvars` at it:

```hcl
instructors = {
  mei = { vms = 2, requirements = "reqs/mei.txt" }
}
```

On `terraform apply`, the file's contents are baked into the cloud-init and run
as `uv pip install -r ...` into the shared GPU venv (`/opt/glamacles/venv`) on
**every** one of that instructor's VMs — so a multi-VM instructor gets identical
environments without setting each one up by hand.

These install on top of the baseline (PyTorch, JAX, numpy/scipy/pandas, etc.), so
only list what's *extra*. Example `reqs/mei.txt`:

```
segmentation-models-pytorch
rioxarray
einops
```

Paths are relative to the `terraform/` directory. To change an instructor's
requirements later, edit the file and re-run `terraform apply` (note: it rebuilds
those VMs, since user-data changes force replacement).
```
