# Hardening Content

Native CIS control implementations — bash for RHEL 9, PowerShell for Windows Server
2025. No Ansible, no WinRM, no external control node anywhere in this directory. See
[`CONTRACT.md`](CONTRACT.md) for the interface these packages expose to the pipeline
in `infra/terraform/`, and [`../docs/architecture.md`](../docs/architecture.md) for
how the pieces fit together.

- `rhel9-cis/` — ported from the vendored ansible-lockdown role in `../Images/` (used
  only as a reference for correct values; nothing here invokes it).
- `windows-server-2025-cis/` — authored directly from
  `../CIS_Microsoft_Windows_Server_2025_Benchmark_v2.1.0.pdf`.

Each package's `manifest.yml` is the honest source of truth for control coverage —
check `status: implemented` vs `status: planned` there before assuming either OS
package is a complete CIS Level 1/2 implementation.

## Local testing

```bash
# RHEL (run as root on a RHEL9 host/container):
./rhel9-cis/run.sh --mode audit --level 1

# Windows (run elevated):
.\windows-server-2025-cis\run.ps1 -Mode audit -Level 1
```

Always run `audit` before `remediate` on a system you care about — remediate mode
makes real changes.

## Releasing a new version

1. `./package.sh <version>` to produce `dist/rhel9-cis-<version>.tar.gz` and
   `dist/windows2025-cis-<version>.zip`.
2. Upload both to the artifact bucket Terraform created
   (`terraform output artifact_bucket_name` in `infra/terraform/`):
   ```bash
   aws s3 cp dist/rhel9-cis-<version>.tar.gz s3://<bucket>/rhel9-cis/rhel9-cis-<version>.tar.gz
   aws s3 cp dist/windows2025-cis-<version>.zip s3://<bucket>/windows2025-cis/windows2025-cis-<version>.zip
   ```
3. Point the pipeline at the new version by updating the two SSM Parameters (this is
   the only step that makes the new content "live" — every pipeline component
   resolves the artifact through these at execution time, per `CONTRACT.md`):
   ```bash
   aws ssm put-parameter --name /cis-hardening/artifacts/rhel9/s3-uri \
     --value s3://<bucket>/rhel9-cis/rhel9-cis-<version>.tar.gz --type String --overwrite
   aws ssm put-parameter --name /cis-hardening/artifacts/windows2025/s3-uri \
     --value s3://<bucket>/windows2025-cis/windows2025-cis-<version>.zip --type String --overwrite
   ```

No Terraform apply is required for a content release — that's the point of the
parameter-indirection seam described in `CONTRACT.md`.
