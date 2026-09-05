output "kms_key_arn" {
  value = aws_kms_key.this.arn
}

output "artifact_bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}

output "artifact_bucket_arn" {
  value = aws_s3_bucket.artifacts.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.pipeline_notifications.arn
}

output "image_builder_instance_profile_name" {
  value = aws_iam_instance_profile.image_builder_instance.name
}

output "image_builder_instance_role_arn" {
  value = aws_iam_role.image_builder_instance.arn
}

output "ssm_automation_role_arn" {
  value = aws_iam_role.ssm_automation.arn
}

output "config_evaluator_lambda_role_arn" {
  value = aws_iam_role.config_evaluator_lambda.arn
}

output "artifact_parameter_name_rhel9" {
  value = aws_ssm_parameter.artifact_uri_rhel9.name
}

output "artifact_parameter_name_windows2025" {
  value = aws_ssm_parameter.artifact_uri_windows2025.name
}

output "tag_key_benchmark" {
  value = var.tag_key_benchmark
}

output "tag_key_level" {
  value = var.tag_key_level
}

output "tag_value_rhel9" {
  value = var.tag_value_rhel9
}

output "tag_value_windows2025" {
  value = var.tag_value_windows2025
}
