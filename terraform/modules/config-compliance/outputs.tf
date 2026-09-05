output "lambda_function_arn" {
  value = aws_lambda_function.compliance_evaluator.arn
}

output "conformance_pack_name" {
  value = aws_config_conformance_pack.cis_hardening.name
}
