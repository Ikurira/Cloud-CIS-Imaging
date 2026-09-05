variable "name_prefix" {
  type    = string
  default = "cis-hardening"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "artifact_parameter_name" {
  description = "Name of the SSM Parameter (from modules/shared) that resolves to the current Windows Server 2025 hardening-content S3 URI. Read at build time by the component, never baked in as a value."
  type        = string
}

variable "instance_profile_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "sns_topic_arn" {
  type = string
}

variable "cis_level" {
  type    = number
  default = 1
  validation {
    condition     = contains([1, 2], var.cis_level)
    error_message = "cis_level must be 1 or 2."
  }
}

variable "cis_profile" {
  type    = string
  default = "server"
}

variable "base_ami_ssm_parameter" {
  description = "AWS-published public SSM parameter that resolves to the latest base Windows Server 2025 AMI."
  type        = string
  default     = "/aws/service/ami-windows-latest/Windows_Server-2025-English-Full-Base"
}

variable "instance_types" {
  type    = list(string)
  default = ["m5.xlarge"]
}

variable "landing_zone_account_ids" {
  type    = list(string)
  default = []
}

variable "distribution_regions" {
  type    = list(string)
  default = []
}

variable "pipeline_schedule_expression" {
  type    = string
  default = "cron(0 8 ? * SUN *)"
}

variable "kms_key_arn" {
  type = string
}

variable "tag_key_benchmark" {
  type = string
}

variable "tag_key_level" {
  type = string
}

variable "tag_value_windows2025" {
  type = string
}
