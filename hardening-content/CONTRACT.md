# Hardening Content Contract

This defines the interface between the hardening scripts (this directory) and every
orchestration layer that invokes them (EC2 Image Builder components, SSM State Manager
associations, SSM Automation auto-remediation runbooks). No layer calls another layer's
code directly — every layer only depends on this contract, which is what keeps the
pipeline in `infra/terraform/` loosely coupled to the hardening content itself. Content
can be revised, re-versioned, and re-tested independently of the pipeline as long as the
contract holds.

No component in this repo installs or invokes Ansible, WinRM, or any external configuration-
management control node. Hardening logic is native shell (RHEL) / native PowerShell (Windows)
only, executed locally on the instance being built or enforced.

## Package layout (per OS)

```
hardening-content/<os>/
  manifest.yml            # full control catalog: id, title, section, level, profile, status, script
  lib/                     # shared helper library sourced by every section script
  scripts/
    section_<n>/
      cis_<x.y>.sh|.ps1    # one script per control group (mirrors CIS benchmark numbering)
  run.sh | run.ps1          # top-level runner, the only entrypoint external callers use
```

Each OS package is built into a single versioned artifact:
- RHEL: `rhel9-cis-<version>.tar.gz`
- Windows: `windows2025-cis-<version>.zip`

uploaded to the shared artifact S3 bucket (`infra/terraform/modules/shared`). The bucket key
of the *current* artifact for each OS is published as an SSM Parameter:

- `/cis-hardening/artifacts/rhel9/s3-uri`
- `/cis-hardening/artifacts/windows2025/s3-uri`

Every caller (Image Builder component, SSM document) resolves the artifact location by
reading that parameter at execution time — never a hardcoded key, never a Terraform
cross-module reference. Bumping content is a content-repo release + one parameter update;
it never requires touching the pipeline Terraform.

## Runner CLI

```
run.sh   --mode audit|remediate --level 1|2 [--profile server|workstation] [--section N]
run.ps1  -Mode audit|remediate  -Level 1|2   [-Profile server|workstation] [-Section N]
```

- `audit`     — check-only, makes no changes.
- `remediate` — applies fixes, safe to re-run (idempotent).
- `--level`   — CIS Level 1 or Level 2 (Level 1 is a subset always included in Level 2 runs).
- Exit code   — number of non-compliant/failed controls found at end of run (`0` = fully
  compliant). This is what fails an Image Builder build in the validate phase.

## Result stream (the compliance interface)

Every control emits exactly one JSON line to stdout **and** appends it to a local results
file, via the shared `log_result` helper in `lib/`:

```json
{"control_id":"1.1.1.1","title":"Ensure cramfs kernel module is not available","section":"1","level":1,"status":"pass|fail|error|skipped","mode":"audit|remediate","message":"...","timestamp":"2026-09-05T12:00:00Z"}
```

- Linux results file: `/var/log/cis-hardening/results.jsonl`
- Windows results file: `C:\ProgramData\CISHardening\results.jsonl`

The SSM documents in `infra/terraform/modules/ssm-enforcement` read this file after invoking
`run.sh`/`run.ps1` and translate it into `aws ssm put-compliance-items` calls with
`compliance-type Custom:CIS-RHEL9` or `Custom:CIS-WindowsServer2025`. That SSM Compliance data
is what `infra/terraform/modules/config-compliance`'s Lambda-backed Config rule reads — Config
never touches the instance or the scripts directly.

## Tag contract (how instances get in scope)

Every AMI and every EC2 instance built from it carries:

- `CISBenchmark`      = `RHEL9` | `WindowsServer2025`
- `CISBenchmarkLevel` = `1` | `2`

State Manager associations, the Config rule's scope, and the automation runbook all key off
these two tags — nothing references an instance ID or AMI ID directly except at remediation
time, when Config passes the specific non-compliant `InstanceId` to the automation runbook.

## Manifest schema (`manifest.yml`)

```yaml
- id: "1.1.1.1"
  title: "Ensure cramfs kernel module is not available"
  section: "1"
  level: 1
  profile: [server, workstation]
  status: implemented   # implemented | planned
  script: scripts/section_1/cis_1.1.1.x.sh
```

`status: planned` entries are real, catalogued gaps, not silent omissions — every control in
the applicable CIS benchmark PDF is listed here even if not yet scripted.
