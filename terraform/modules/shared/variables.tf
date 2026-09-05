variable "name_prefix" {
  type    = string
  default = "cis-hardening"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "tag_key_benchmark" {
  description = "Tag key applied to AMIs/instances identifying which CIS benchmark applies."
  type        = string
  default     = "CISBenchmark"
}

variable "tag_key_level" {
  description = "Tag key applied to AMIs/instances recording the enforced CIS level."
  type        = string
  default     = "CISBenchmarkLevel"
}

variable "tag_value_rhel9" {
  type    = string
  default = "RHEL9"
}

variable "tag_value_windows2025" {
  type    = string
  default = "WindowsServer2025"
}

variable "landing_zone_account_ids" {
  description = "Accounts granted decrypt access to the KMS key and read access to the artifact bucket, so hardening content and AMIs can be consumed cross-account."
  type        = list(string)
  default     = []
}
