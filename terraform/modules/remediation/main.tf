resource "aws_ssm_document" "auto_remediate" {
  name            = "${var.name_prefix}-auto-remediate"
  document_type   = "Automation"
  document_format = "YAML"

  content = templatefile("${path.module}/documents/auto-remediate.yaml.tftpl", {
    automation_role_arn = var.automation_role_arn
    sns_topic_arn        = var.sns_topic_arn
  })

  tags = var.tags
}
