variable "name_prefix" {
  type    = string
  default = "cis-hardening"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "tag_key_benchmark" {
  type = string
}

variable "tag_value_rhel9" {
  type = string
}

variable "tag_value_windows2025" {
  type = string
}

variable "artifact_parameter_name_rhel9" {
  type = string
}

variable "artifact_parameter_name_windows2025" {
  type = string
}

variable "cis_level" {
  type    = number
  default = 1
}

variable "cis_profile" {
  type    = string
  default = "server"
}

variable "enforcement_schedule" {
  description = "SSM State Manager association schedule (rate() or cron()) controlling how often continuous enforcement re-runs."
  type        = string
  default     = "rate(1 day)"
}

variable "compliance_severity" {
  description = "Severity State Manager reports for association-level compliance (distinct from per-control severity in the compliance items themselves)."
  type        = string
  default     = "HIGH"
}
