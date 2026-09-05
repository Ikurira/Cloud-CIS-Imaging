variable "name_prefix" {
  type    = string
  default = "cis-hardening"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "artifact_parameter_name" {
  description = "Name of the SSM Parameter (from modules/shared) that resolves to the current RHEL9 hardening-content S3 URI. Read at build time by the component, never baked in as a value."
  type        = string
}

variable "instance_profile_name" {
  description = "Instance profile (from modules/shared) attached to the build instance."
  type        = string
}

variable "subnet_id" {
  description = "Subnet the transient Image Builder build instance launches into."
  type        = string
}

variable "security_group_ids" {
  description = "Security groups for the transient build instance (outbound HTTPS to S3/SSM/dnf mirrors is required)."
  type        = list(string)
}

variable "sns_topic_arn" {
  description = "Pipeline notification topic (from modules/shared)."
  type        = string
}

variable "cis_level" {
  description = "CIS level to build/validate against (1 or 2)."
  type        = number
  default     = 1
  validation {
    condition     = contains([1, 2], var.cis_level)
    error_message = "cis_level must be 1 or 2."
  }
}

variable "cis_profile" {
  description = "CIS profile: server or workstation."
  type        = string
  default     = "server"
}

variable "base_ami_owner" {
  description = "AMI owner account ID to source the base RHEL9 image from. Defaults to Red Hat's official publisher account."
  type        = string
  default     = "309956199498"
}

variable "base_ami_name_pattern" {
  description = "Name filter for the base RHEL9 AMI lookup."
  type        = string
  default     = "RHEL-9*_HVM-*-x86_64-*-Hourly2-GP3"
}

variable "instance_types" {
  description = "Instance types Image Builder is allowed to use for the transient build/test instance."
  type        = list(string)
  default     = ["m5.large"]
}

variable "landing_zone_account_ids" {
  description = "Landing zone account IDs the resulting hardened AMI is distributed to."
  type        = list(string)
  default     = []
}

variable "distribution_regions" {
  description = "Regions to copy/distribute the hardened AMI into, in addition to the build region."
  type        = list(string)
  default     = []
}

variable "pipeline_schedule_expression" {
  description = "Cron expression controlling how often the pipeline rebuilds the hardened AMI (picks up base-AMI patches and refreshed hardening content)."
  type        = string
  default     = "cron(0 6 ? * SUN *)"
}

variable "kms_key_arn" {
  description = "KMS key used to encrypt the distributed AMI's backing snapshot."
  type        = string
}

variable "tag_key_benchmark" {
  description = "Tag key contract published by modules/shared."
  type        = string
}

variable "tag_key_level" {
  description = "Tag key contract published by modules/shared."
  type        = string
}

variable "tag_value_rhel9" {
  description = "Tag value contract published by modules/shared."
  type        = string
}
