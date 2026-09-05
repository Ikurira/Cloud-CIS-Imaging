variable "aws_region" {
  description = "Home region for the pipeline (Image Builder pipelines, SSM, Config, Lambda). Distribution can still target other regions."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Short name used as a prefix for all resources and the tag/parameter contract shared across every module."
  type        = string
  default     = "cis-hardening"
}

variable "tags" {
  description = "Common tags merged onto every resource in the pipeline."
  type        = map(string)
  default     = {}
}

variable "landing_zone_account_ids" {
  description = "AWS account IDs (landing zone / spoke accounts) that hardened AMIs are distributed to, and that are granted read access to the hardening-content artifact bucket/KMS key so their instances can run continuous enforcement too."
  type        = list(string)
  default     = []
}

variable "distribution_regions" {
  description = "Regions the hardened AMIs are distributed to, in addition to aws_region."
  type        = list(string)
  default     = []
}

variable "cis_level" {
  description = "CIS Benchmark level enforced by the pipeline (1 or 2). Level 2 includes all Level 1 controls."
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

variable "enforcement_schedule" {
  description = "SSM State Manager association schedule expression for continuous drift enforcement."
  type        = string
  default     = "rate(1 day)"
}

variable "notification_email" {
  description = "Optional email address subscribed to the pipeline SNS topic (build state changes, drift, remediation). Leave empty to skip the subscription."
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC used for the Image Builder infrastructure configuration (transient build/test instances). Only required for reference/documentation — the subnet already implies the VPC."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet used for Image Builder build/test instances. Must have a route to the internet or VPC endpoints for SSM, S3, and Image Builder/dnf mirrors."
  type        = string
}

variable "security_group_ids" {
  description = "Security groups attached to Image Builder build/test instances."
  type        = list(string)
}

variable "instance_type_rhel" {
  description = "Instance type used to build/test the RHEL9 image."
  type        = string
  default     = "m5.large"
}

variable "instance_type_windows" {
  description = "Instance type used to build/test the Windows Server 2025 image."
  type        = string
  default     = "m5.xlarge"
}

variable "rhel_pipeline_schedule" {
  type    = string
  default = "cron(0 6 ? * SUN *)"
}

variable "windows_pipeline_schedule" {
  type    = string
  default = "cron(0 8 ? * SUN *)"
}
