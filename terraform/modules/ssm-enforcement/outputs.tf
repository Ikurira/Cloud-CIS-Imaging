output "enforce_document_name_rhel9" {
  value = aws_ssm_document.enforce_rhel9.name
}

output "enforce_document_arn_rhel9" {
  value = aws_ssm_document.enforce_rhel9.arn
}

output "enforce_document_name_windows2025" {
  value = aws_ssm_document.enforce_windows2025.name
}

output "enforce_document_arn_windows2025" {
  value = aws_ssm_document.enforce_windows2025.arn
}
