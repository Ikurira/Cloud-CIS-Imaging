# Continuous enforcement: on a schedule, re-download the current hardening
# artifact, run it in remediate mode, and publish results into SSM Compliance.
# Coupling to modules/config-compliance is via the ComplianceType string
# convention and the SSM Compliance API — not a Terraform reference.

resource "aws_ssm_document" "enforce_rhel9" {
  name            = "${var.name_prefix}-enforce-rhel9"
  document_type   = "Command"
  document_format = "YAML"
  content         = file("${path.module}/documents/enforce-rhel9.yaml")
  target_type     = "/AWS::EC2::Instance"
  tags            = var.tags
}

resource "aws_ssm_document" "enforce_windows2025" {
  name            = "${var.name_prefix}-enforce-windows2025"
  document_type   = "Command"
  document_format = "YAML"
  content         = file("${path.module}/documents/enforce-windows2025.yaml")
  target_type     = "/AWS::EC2::Instance"
  tags            = var.tags
}

resource "aws_ssm_association" "enforce_rhel9" {
  name             = aws_ssm_document.enforce_rhel9.name
  association_name = "${var.name_prefix}-enforce-rhel9"

  targets {
    key    = "tag:${var.tag_key_benchmark}"
    values = [var.tag_value_rhel9]
  }

  schedule_expression         = var.enforcement_schedule
  apply_only_at_cron_interval = false
  compliance_severity         = var.compliance_severity
  max_concurrency             = "50%"
  max_errors                  = "25%"

  parameters = {
    ArtifactParameterName = var.artifact_parameter_name_rhel9
    CisLevel               = tostring(var.cis_level)
    CisProfile             = var.cis_profile
    ComplianceType         = "Custom:CIS-RHEL9"
  }
}

resource "aws_ssm_association" "enforce_windows2025" {
  name             = aws_ssm_document.enforce_windows2025.name
  association_name = "${var.name_prefix}-enforce-windows2025"

  targets {
    key    = "tag:${var.tag_key_benchmark}"
    values = [var.tag_value_windows2025]
  }

  schedule_expression         = var.enforcement_schedule
  apply_only_at_cron_interval = false
  compliance_severity         = var.compliance_severity
  max_concurrency             = "50%"
  max_errors                  = "25%"

  parameters = {
    ArtifactParameterName = var.artifact_parameter_name_windows2025
    CisLevel               = tostring(var.cis_level)
    CisProfile              = var.cis_profile
    ComplianceType          = "Custom:CIS-WindowsServer2025"
  }
}

# Published so modules/remediation (and anything else) can discover these
# documents by name/parameter lookup instead of a Terraform module reference
# — the automation runbook re-invokes the same enforcement document that
# State Manager uses, targeted at one instance.
resource "aws_ssm_parameter" "enforce_document_name_rhel9" {
  name  = "/${var.name_prefix}/ssm-documents/rhel9/enforce-name"
  type  = "String"
  value = aws_ssm_document.enforce_rhel9.name
  tags  = var.tags
}

resource "aws_ssm_parameter" "enforce_document_name_windows2025" {
  name  = "/${var.name_prefix}/ssm-documents/windows2025/enforce-name"
  type  = "String"
  value = aws_ssm_document.enforce_windows2025.name
  tags  = var.tags
}
