output "artifact_bucket_name" {
  description = "Upload target for hardening-content releases (hardening-content/rhel9-cis and hardening-content/windows-server-2025-cis)."
  value       = module.shared.artifact_bucket_name
}

output "rhel9_pipeline_arn" {
  value = module.image_builder_rhel.pipeline_arn
}

output "windows2025_pipeline_arn" {
  value = module.image_builder_windows.pipeline_arn
}

output "conformance_pack_name" {
  value = module.config_compliance.conformance_pack_name
}

output "sns_topic_arn" {
  value = module.shared.sns_topic_arn
}
