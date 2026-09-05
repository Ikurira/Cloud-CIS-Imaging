variable "name_prefix" {
  type    = string
  default = "cis-hardening"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "automation_role_arn" {
  description = "SSM Automation execution role (from modules/shared)."
  type        = string
}

variable "sns_topic_arn" {
  description = "Pipeline notification topic (from modules/shared)."
  type        = string
}
