data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# KMS key — encrypts the artifact bucket and is available for SSM/Config use.
# ---------------------------------------------------------------------------

resource "aws_kms_key" "this" {
  description             = "${var.name_prefix} artifact & pipeline encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-key" })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name_prefix}"
  target_key_id = aws_kms_key.this.key_id
}

# ---------------------------------------------------------------------------
# Hardening content artifact bucket — the single hand-off point between the
# hardening-content repo/CI and every pipeline component. Producers upload a
# versioned tarball/zip here and bump the matching SSM Parameter; consumers
# (Image Builder components, SSM documents) always resolve the artifact
# location through that parameter, never a hardcoded key. See
# hardening-content/CONTRACT.md.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-artifacts" })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Landing-zone instances (not just the build-account instance) run the SSM
# enforcement documents in modules/ssm-enforcement, so they need to be able to
# pull the artifact and decrypt it too — grant, don't re-architect the bucket.
data "aws_iam_policy_document" "artifacts_cross_account" {
  count = length(var.landing_zone_account_ids) > 0 ? 1 : 0

  statement {
    sid       = "LandingZoneRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.artifacts.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [for id in var.landing_zone_account_ids : "arn:aws:iam::${id}:root"]
    }
  }
  statement {
    sid       = "LandingZoneList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.artifacts.arn]
    principals {
      type        = "AWS"
      identifiers = [for id in var.landing_zone_account_ids : "arn:aws:iam::${id}:root"]
    }
  }
}

resource "aws_s3_bucket_policy" "artifacts_cross_account" {
  count  = length(var.landing_zone_account_ids) > 0 ? 1 : 0
  bucket = aws_s3_bucket.artifacts.id
  policy = data.aws_iam_policy_document.artifacts_cross_account[0].json
}

resource "aws_kms_grant" "landing_zone_decrypt" {
  for_each          = toset(var.landing_zone_account_ids)
  name              = "${var.name_prefix}-landing-zone-${each.value}"
  key_id            = aws_kms_key.this.key_id
  grantee_principal = "arn:aws:iam::${each.value}:root"
  operations        = ["Decrypt", "DescribeKey"]
}

# Placeholder pointers — real values are written by the hardening-content
# release process (CI), not by Terraform. Terraform only creates the
# parameter so consumers have a stable name to read from day one, and only
# ever manages it thereafter via lifecycle.ignore_changes so a CI-driven
# content release is never reverted by a subsequent `terraform apply`.
resource "aws_ssm_parameter" "artifact_uri_rhel9" {
  name  = "/${var.name_prefix}/artifacts/rhel9/s3-uri"
  type  = "String"
  value = "s3://${aws_s3_bucket.artifacts.bucket}/rhel9-cis/UNRELEASED"
  tags  = var.tags

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "artifact_uri_windows2025" {
  name  = "/${var.name_prefix}/artifacts/windows2025/s3-uri"
  type  = "String"
  value = "s3://${aws_s3_bucket.artifacts.bucket}/windows2025-cis/UNRELEASED"
  tags  = var.tags

  lifecycle {
    ignore_changes = [value]
  }
}

# ---------------------------------------------------------------------------
# Tag contract — published so modules deployed from a separate Terraform
# state can still agree on the same keys/values without a code reference.
# ---------------------------------------------------------------------------

resource "aws_ssm_parameter" "tag_key_benchmark" {
  name  = "/${var.name_prefix}/tags/benchmark-key"
  type  = "String"
  value = var.tag_key_benchmark
  tags  = var.tags
}

resource "aws_ssm_parameter" "tag_key_level" {
  name  = "/${var.name_prefix}/tags/level-key"
  type  = "String"
  value = var.tag_key_level
  tags  = var.tags
}

# ---------------------------------------------------------------------------
# Notifications — every module publishes to this one topic (pipeline
# completion, drift detected, remediation fired) instead of calling each
# other directly. Subscribe whatever you want downstream (Slack, ticketing,
# Security Hub) without touching the producing modules.
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "pipeline_notifications" {
  name              = "${var.name_prefix}-notifications"
  kms_master_key_id = aws_kms_key.this.id
  tags              = var.tags
}

data "aws_iam_policy_document" "sns_publish" {
  statement {
    sid       = "AllowEventBridgePublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.pipeline_notifications.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "config.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "pipeline_notifications" {
  arn    = aws_sns_topic.pipeline_notifications.arn
  policy = data.aws_iam_policy_document.sns_publish.json
}

resource "aws_ssm_parameter" "sns_topic_arn" {
  name  = "/${var.name_prefix}/sns/pipeline-topic-arn"
  type  = "String"
  value = aws_sns_topic.pipeline_notifications.arn
  tags  = var.tags
}

# ---------------------------------------------------------------------------
# IAM — Image Builder instance role/profile. One role, shared by both OS
# recipes: it only needs to read the artifact bucket and talk to SSM/Image
# Builder, nothing OS-specific.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "image_builder_instance" {
  name               = "${var.name_prefix}-image-builder-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "image_builder_core" {
  role       = aws_iam_role.image_builder_instance.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

resource "aws_iam_role_policy_attachment" "image_builder_ssm_core" {
  role       = aws_iam_role.image_builder_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "artifact_read" {
  statement {
    sid       = "ReadHardeningArtifacts"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.artifacts.arn}/*"]
  }
  statement {
    sid       = "ListHardeningArtifacts"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.artifacts.arn]
  }
  statement {
    sid       = "DecryptArtifacts"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [aws_kms_key.this.arn]
  }
}

resource "aws_iam_policy" "artifact_read" {
  name   = "${var.name_prefix}-artifact-read"
  policy = data.aws_iam_policy_document.artifact_read.json
}

resource "aws_iam_role_policy_attachment" "image_builder_artifact_read" {
  role       = aws_iam_role.image_builder_instance.name
  policy_arn = aws_iam_policy.artifact_read.arn
}

resource "aws_iam_instance_profile" "image_builder_instance" {
  name = "${var.name_prefix}-image-builder-instance"
  role = aws_iam_role.image_builder_instance.name
}

# ---------------------------------------------------------------------------
# IAM — SSM Automation role, used by the auto-remediation runbook
# (modules/remediation) to invoke Run Command against a target instance.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ssm_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm_automation" {
  name               = "${var.name_prefix}-ssm-automation"
  assume_role_policy = data.aws_iam_policy_document.ssm_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "ssm_automation_permissions" {
  statement {
    sid = "RunAndTrackCommands"
    actions = [
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
      "ssm:DescribeInstanceInformation",
    ]
    resources = ["*"]
  }
  statement {
    sid       = "DescribeInstances"
    actions   = ["ec2:DescribeInstances", "ec2:DescribeTags"]
    resources = ["*"]
  }
  statement {
    sid       = "Notify"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.pipeline_notifications.arn]
  }
}

resource "aws_iam_policy" "ssm_automation" {
  name   = "${var.name_prefix}-ssm-automation"
  policy = data.aws_iam_policy_document.ssm_automation_permissions.json
}

resource "aws_iam_role_policy_attachment" "ssm_automation" {
  role       = aws_iam_role.ssm_automation.name
  policy_arn = aws_iam_policy.ssm_automation.arn
}

# ---------------------------------------------------------------------------
# IAM — Lambda execution role for the custom Config rule evaluator.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config_evaluator_lambda" {
  name               = "${var.name_prefix}-config-evaluator"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "config_evaluator_basic" {
  role       = aws_iam_role.config_evaluator_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "config_evaluator_permissions" {
  statement {
    sid = "ReadSsmCompliance"
    actions = [
      "ssm:ListComplianceItems",
      "ssm:ListResourceComplianceSummaries",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
    ]
    resources = ["*"]
  }
  statement {
    sid       = "ReportToConfig"
    actions   = ["config:PutEvaluations"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "config_evaluator" {
  name   = "${var.name_prefix}-config-evaluator"
  policy = data.aws_iam_policy_document.config_evaluator_permissions.json
}

resource "aws_iam_role_policy_attachment" "config_evaluator" {
  role       = aws_iam_role.config_evaluator_lambda.name
  policy_arn = aws_iam_policy.config_evaluator.arn
}
