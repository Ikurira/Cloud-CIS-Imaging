# CIS Cloud-Native Hardening Pipeline — CloudFormation

A CloudFormation port of `infra/terraform/`, for deploying and testing straight from
the AWS Console (Services → CloudFormation → **Create stack** → *Upload a template
file*). Functionally equivalent to the Terraform version, with two simplifications
called out below. See [`../../docs/architecture.md`](../../docs/architecture.md) for
the overall design — it still applies; the loose-coupling mechanism here is
CloudFormation **cross-stack Exports/`Fn::ImportValue`** in place of Terraform module
outputs/inputs, same tag and SSM-parameter contract otherwise.

## Deploy order

Six stacks, deployed in this order, **all with the same `NamePrefix` parameter value**
(default `cis-hardening` — just leave it as the default on every stack unless you
have a reason to change it):

| # | Template | Depends on |
|---|---|---|
| 1 | `00-shared.yaml` | — |
| 2 | `01-image-builder-rhel.yaml` | 1 |
| 2 | `01-image-builder-windows.yaml` | 1 |
| 3 | `02-ssm-enforcement.yaml` | 1 |
| 4 | `03-remediation.yaml` | 1 |
| 5 | `04-config-compliance.yaml` | 1, 3, 4 |

Stacks at the same number can be deployed in either order / in parallel. Deploy
`04-config-compliance.yaml` last — it imports document/role names from stacks 1, 3,
and 4.

## Parameters you'll be asked for

- **00-shared.yaml**: everything has a sane default. Leave `LandingZoneAccountRootArns`
  empty for a single-account test.
- **01-image-builder-rhel.yaml**: needs `BaseAmiId` (Red Hat doesn't publish a public
  SSM parameter for their AMI — the template description field gives you the exact
  `aws ec2 describe-images` command to find one), `SubnetId`, and
  `SecurityGroupIds`.
- **01-image-builder-windows.yaml**: needs `SubnetId` and `SecurityGroupIds` only —
  `BaseAmiId` defaults to AWS's public SSM parameter for the latest Windows Server
  2025 AMI.
- **02-ssm-enforcement.yaml**, **03-remediation.yaml**, **04-config-compliance.yaml**:
  everything has a default; just confirm `NamePrefix` matches.

## Before any of this does anything useful

The Image Builder components and SSM documents all resolve the hardening-content
artifact from an SSM Parameter that `00-shared.yaml` creates pointing at
`.../UNRELEASED`. Package and upload the content once — see
[`../../hardening-content/README.md`](../../hardening-content/README.md) — before
running an Image Builder pipeline or an SSM association, or those steps will fail at
the download step with an obvious error.

`04-config-compliance.yaml` also assumes an AWS Config configuration recorder +
delivery channel already exist in this account/region (Config → Settings, if you've
never turned it on).

## To actually see compliance/remediation fire

Launch an EC2 instance from the hardened AMI (or any RHEL9/Windows Server 2025
instance for a quick test) and **tag it yourself**: `CISBenchmark` = `RHEL9` or
`WindowsServer2025` (plus `CISBenchmarkLevel` = `1`, optional). Image Builder only
tags the *AMI*; nothing here creates the ASG/Launch Template that would tag instances
automatically at launch (that's your own downstream infrastructure, per the "EC2
Instances Launched" box in the architecture diagram) — so an instance you launch by
hand needs the tag added manually or it won't be picked up by the SSM association or
the Config rule.

## Known differences from the Terraform version (simplified for console testing)

- **Single-region distribution only.** The Terraform version loops over a
  `distribution_regions` list; CloudFormation has no native way to loop a resource
  block over a parameter list without enabling Language Extensions, so this port
  only distributes the AMI to its build region. Add more `Distributions` list entries
  by hand in `01-image-builder-*.yaml` if you need another region.
- **Tag keys are literal**, not parameterized. `ResourceTags`/`AmiTags` are
  CloudFormation "Map" properties, which require literal string keys — no intrinsic
  function can compute a map *key* (only values). They're hardcoded as
  `CISBenchmark`/`CISBenchmarkLevel` to match `00-shared.yaml`'s defaults; if you
  change `TagKeyBenchmark`/`TagKeyLevel` away from those defaults there, update the
  literal keys in `01-image-builder-rhel.yaml` and `01-image-builder-windows.yaml` to
  match.

## Tearing down

Delete in reverse order (5 → 1). `04-config-compliance.yaml`'s conformance pack takes
a few minutes to delete. The artifact S3 bucket in `00-shared.yaml` won't delete while
it has objects in it — empty it first if you want a clean `delete-stack`.
