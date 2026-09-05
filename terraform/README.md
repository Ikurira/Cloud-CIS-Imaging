# CIS Cloud-Native Hardening Pipeline — Terraform

Implements `Images/cis-hardening-architecture.drawio`'s target state (Group 2). See
[`../docs/architecture.md`](../docs/architecture.md) for the full design and the
loose-coupling rationale before changing anything here.

## Prerequisites

- An AWS Config configuration recorder + delivery channel already enabled in the
  account (this stack only adds a conformance pack on top of it).
- A subnet with a route to SSM/S3/Image Builder VPC endpoints or the internet, for
  the transient Image Builder build/test instances.
- `hardening-content/` packaged and uploaded at least once (see
  `hardening-content/README.md`) — the pipeline will build successfully before that,
  but the Image Builder components will fail at the `DownloadHardeningArtifact` step
  until the SSM parameters point at a real object.

## Usage

```bash
terraform init
terraform plan \
  -var subnet_id=subnet-xxxxxxxx \
  -var 'security_group_ids=["sg-xxxxxxxx"]' \
  -var 'landing_zone_account_ids=["111111111111","222222222222"]' \
  -var notification_email=security-team@example.com
terraform apply
```

All other variables (`cis_level`, `cis_profile`, schedules, instance types, tag
contract) have sane defaults — see `variables.tf`.

## Module map

| Module | Diagram box | Depends on |
|---|---|---|
| `modules/shared` | (cross-cutting: KMS, artifact bucket, IAM, tag contract) | — |
| `modules/image-builder-rhel` | CIS Controls → Image Builder Components → Recipe → Pipeline → Distribution (RHEL9) | `shared` (parameters/roles only) |
| `modules/image-builder-windows` | same, Windows Server 2025 | `shared` |
| `modules/ssm-enforcement` | SSM State Manager Association (Continuous Enforcement) | `shared` |
| `modules/remediation` | SSM Automation Runbook (Auto-Remediation) | `shared` |
| `modules/config-compliance` | AWS Config Conformance Pack (CIS Benchmark Evaluation) | `shared`, `remediation`, `ssm-enforcement` (document/role names only — see architecture doc for why this is the one unavoidable ordering) |

Each module also has its own file-level comments explaining the resources it owns.
