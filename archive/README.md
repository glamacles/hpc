# Archived: bash + OpenStack CLI provisioning

These scripts (`config.sh`, `lib.sh`, `scripts/`, `cloud-init/`) were the first
implementation of the GLAMacles provisioning. They worked, but we moved to
**Terraform** ([../terraform/](../terraform/)) as the single source of truth —
it gives a state file, idempotent `apply`, and reliable `destroy`.

Kept here for reference only. They are **not maintained** and lag behind the
Terraform config (e.g. they still use the old project-label model instead of the
instructor-keyed one, and lack the per-instructor requirements feature). Don't
run them against the same allocation as Terraform — they'd create duplicate,
unmanaged resources.

To provision, use [../terraform/README.md](../terraform/README.md).
