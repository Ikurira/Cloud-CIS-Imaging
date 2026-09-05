output "automation_document_name" {
  value = aws_ssm_document.auto_remediate.name
}

output "automation_document_arn" {
  value = aws_ssm_document.auto_remediate.arn
}
