# Root wiring for the cloud-native CIS hardening pipeline (see
# Images/cis-hardening-architecture.drawio, "Group 2: Cloud-Native Pipeline").
#
# Every module below is independently deployable — nothing here does more
# than pass through the tag/parameter contract published by modules/shared.
# A team could later split any of these into its own Terraform state/repo by
# swapping the module input for an `aws_ssm_parameter` data source lookup of
# the same value; no module's internal resources reference another module's
# resources directly. See hardening-content/CONTRACT.md for the full contract.

module "shared" {
  source = "./modules/shared"

  name_prefix              = var.name_prefix
  tags                     = var.tags
  landing_zone_account_ids = var.landing_zone_account_ids
}

module "image_builder_rhel" {
  source = "./modules/image-builder-rhel"

  name_prefix              = var.name_prefix
  tags                     = var.tags
  artifact_parameter_name  = module.shared.artifact_parameter_name_rhel9
  instance_profile_name    = module.shared.image_builder_instance_profile_name
  subnet_id                = var.subnet_id
  security_group_ids       = var.security_group_ids
  sns_topic_arn            = module.shared.sns_topic_arn
  cis_level                = var.cis_level
  cis_profile              = var.cis_profile
  instance_types           = [var.instance_type_rhel]
  landing_zone_account_ids = var.landing_zone_account_ids
  distribution_regions     = var.distribution_regions
  kms_key_arn              = module.shared.kms_key_arn
  tag_key_benchmark        = module.shared.tag_key_benchmark
  tag_key_level            = module.shared.tag_key_level
  tag_value_rhel9          = module.shared.tag_value_rhel9
  pipeline_schedule_expression = var.rhel_pipeline_schedule
}

module "image_builder_windows" {
  source = "./modules/image-builder-windows"

  name_prefix              = var.name_prefix
  tags                     = var.tags
  artifact_parameter_name  = module.shared.artifact_parameter_name_windows2025
  instance_profile_name    = module.shared.image_builder_instance_profile_name
  subnet_id                = var.subnet_id
  security_group_ids       = var.security_group_ids
  sns_topic_arn            = module.shared.sns_topic_arn
  cis_level                = var.cis_level
  cis_profile              = var.cis_profile
  instance_types           = [var.instance_type_windows]
  landing_zone_account_ids = var.landing_zone_account_ids
  distribution_regions     = var.distribution_regions
  kms_key_arn              = module.shared.kms_key_arn
  tag_key_benchmark        = module.shared.tag_key_benchmark
  tag_key_level            = module.shared.tag_key_level
  tag_value_windows2025    = module.shared.tag_value_windows2025
  pipeline_schedule_expression = var.windows_pipeline_schedule
}

module "ssm_enforcement" {
  source = "./modules/ssm-enforcement"

  name_prefix                         = var.name_prefix
  tags                                = var.tags
  tag_key_benchmark                   = module.shared.tag_key_benchmark
  tag_value_rhel9                     = module.shared.tag_value_rhel9
  tag_value_windows2025               = module.shared.tag_value_windows2025
  artifact_parameter_name_rhel9       = module.shared.artifact_parameter_name_rhel9
  artifact_parameter_name_windows2025 = module.shared.artifact_parameter_name_windows2025
  cis_level                           = var.cis_level
  cis_profile                         = var.cis_profile
  enforcement_schedule                = var.enforcement_schedule
}

module "remediation" {
  source = "./modules/remediation"

  name_prefix          = var.name_prefix
  tags                 = var.tags
  automation_role_arn  = module.shared.ssm_automation_role_arn
  sns_topic_arn        = module.shared.sns_topic_arn
}

# The only module that needs another module's resource to exist first: AWS
# Config's Remediation Configuration hard-references the automation document
# by name at the API level, so config-compliance must be applied after
# remediation and ssm-enforcement. That ordering is expressed here, once, in
# root wiring — none of those three modules reference each other internally.
module "config_compliance" {
  source = "./modules/config-compliance"

  name_prefix                       = var.name_prefix
  tags                              = var.tags
  lambda_role_arn                   = module.shared.config_evaluator_lambda_role_arn
  tag_key_benchmark                 = module.shared.tag_key_benchmark
  tag_value_rhel9                   = module.shared.tag_value_rhel9
  tag_value_windows2025             = module.shared.tag_value_windows2025
  automation_document_name          = module.remediation.automation_document_name
  automation_assume_role_arn        = module.shared.ssm_automation_role_arn
  enforce_document_name_rhel9       = module.ssm_enforcement.enforce_document_name_rhel9
  enforce_document_name_windows2025 = module.ssm_enforcement.enforce_document_name_windows2025
}

resource "aws_sns_topic_subscription" "notification_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = module.shared.sns_topic_arn
  protocol  = "email"
  endpoint  = var.notification_email
}
