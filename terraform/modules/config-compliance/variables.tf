variable "name_prefix" {
  type    = string
  default = "cis-hardening"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "lambda_role_arn" {
  description = "Execution role for the compliance-evaluator Lambda (from modules/shared)."
  type        = string
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

variable "automation_document_name" {
  description = "Name of the generic auto-remediation SSM Automation document (from modules/remediation) that every Config Remediation Configuration in the conformance pack targets."
  type        = string
}

variable "automation_assume_role_arn" {
  description = "Role the SSM Automation remediation runs as (from modules/shared)."
  type        = string
}

variable "enforce_document_name_rhel9" {
  description = "Name of the RHEL9 enforcement SSM document (from modules/ssm-enforcement) that the automation runbook re-invokes on a flagged instance."
  type        = string
}

variable "enforce_document_name_windows2025" {
  description = "Name of the Windows Server 2025 enforcement SSM document (from modules/ssm-enforcement)."
  type        = string
}
