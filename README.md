# Cloud-CIS-Imaging

Automated CIS Benchmark compliance and remediation for AWS — a cloud-native pipeline
that builds CIS-hardened AMIs for **RHEL 9** and **Windows Server 2025**, then keeps
instances built from them compliant for life: continuous drift enforcement, AWS Config
evaluation, and automatic remediation. No Ansible, WinRM, or other external
configuration-management control node anywhere in this repo — hardening logic is
native bash (RHEL) and native PowerShell (Windows), executed locally by whichever
layer calls it.

## What's here

| Directory | What it is |
|---|---|
| [`hardening-content/`](hardening-content/) | The CIS control implementations themselves — native bash for RHEL9, native PowerShell for Windows Server 2025 — plus the interface contract every pipeline layer builds against. |
| [`terraform/`](terraform/) | The pipeline infrastructure as Terraform modules: Image Builder, SSM State Manager, AWS Config, SSM Automation. |
| [`cloudformation/`](cloudformation/) | A CloudFormation port of the same pipeline, deployable stack-by-stack straight from the AWS Console. |

Pick one IaC tool, not both — they provision the same architecture. Terraform is the
more actively maintained, module-per-concern version; CloudFormation trades some
flexibility (see its README for the specific simplifications) for zero tooling install.

## Architecture

```
CIS Controls  →  Image Builder Recipe  →  Image Builder Pipeline  →  Hardened AMI
 (hardening-      (RHEL9 + Windows          (build + validate)         + distributed
  content/)        Server 2025)                                        to accounts/regions
                                                                              │
                                                                              ▼
                                                                    EC2 Instances Launched
                                                                      (your ASG / Launch
                                                                       Template — tag them!)
                                                                        │           │
                                                      enforces baseline │           │ evaluates compliance
                                                                        ▼           ▼
                                                          SSM State Manager   AWS Config
                                                          Association        Conformance Pack
                                                          (continuous            │
                                                           enforcement)          │ non-compliant finding
                                                                                 ▼
                                                                       SSM Automation Runbook
                                                                       (auto-remediation) ─────┐
                                                                                                │
                                                                    remediates (re-runs the     │
                                                                    same enforcement document)  │
                                                                    on the flagged instance ◄────┘
```

One reusable hardening artifact (`hardening-content/<os>/run.sh` or `run.ps1`) is
invoked identically by four different callers — the Image Builder build phase, its
validate phase, the SSM State Manager association, and the auto-remediation
runbook — none of which know about each other. They only share:

- **A tag contract** (`CISBenchmark` / `CISBenchmarkLevel`) that puts an instance in
  scope for enforcement and compliance evaluation.
- **An SSM Parameter** pointing at the current hardening-content artifact in S3, so
  shipping new content is a release + one parameter update, not a redeploy.
- **A JSONL result-stream schema**, documented in
  [`hardening-content/CONTRACT.md`](hardening-content/CONTRACT.md), that every control
  script emits and that gets turned into SSM Compliance data, which AWS Config reads
  back — Config never touches an instance directly.

## Getting started

1. Package and upload the hardening content — [`hardening-content/README.md`](hardening-content/README.md).
2. Deploy the pipeline with either [`terraform/README.md`](terraform/README.md) or
   [`cloudformation/README.md`](cloudformation/README.md).
3. Launch an instance from the resulting hardened AMI, tag it (`CISBenchmark`/
   `CISBenchmarkLevel`), and watch the SSM association and Config rule pick it up.

## Control coverage

- **RHEL9: 297/297 CIS controls implemented.**
- **Windows Server 2025: 153/428 catalogued controls implemented** — Account Lockout
  Policy, User Rights Assignment, Security Options, Windows Defender Firewall,
  Advanced Audit Policy, and a high-value Administrative Templates subset. The rest
  are honestly tracked as `planned` in
  [`hardening-content/windows-server-2025-cis/manifest.yml`](hardening-content/windows-server-2025-cis/manifest.yml)
  (mostly Domain-Controller-only settings not applicable to an EC2 member server, and
  the long tail of Administrative Templates).

See each package's `manifest.yml` for exact per-control status.

## License

[MIT](LICENSE)
