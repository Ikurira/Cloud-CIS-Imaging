provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.name_prefix
      ManagedBy = "terraform"
      Pipeline  = "cis-cloud-native-hardening"
    }
  }
}
