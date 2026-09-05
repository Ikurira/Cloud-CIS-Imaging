data "aws_region" "current" {}

data "aws_ssm_parameter" "windows_base_ami" {
  name = var.base_ami_ssm_parameter
}

resource "aws_imagebuilder_component" "windows2025_cis_harden" {
  name        = "${var.name_prefix}-windows2025-cis-harden"
  description = "Native (PowerShell only, no Ansible/WinRM) CIS Windows Server 2025 hardening: build-time remediate + validate."
  platform    = "Windows"
  version     = "1.0.0"

  data = templatefile("${path.module}/component.yaml.tftpl", {
    artifact_parameter_name = var.artifact_parameter_name
    region                  = data.aws_region.current.name
    cis_level               = var.cis_level
    cis_profile             = var.cis_profile
  })

  tags = var.tags
}

resource "aws_imagebuilder_image_recipe" "windows2025_cis" {
  name         = "${var.name_prefix}-windows2025-cis"
  version      = "1.0.0"
  parent_image = data.aws_ssm_parameter.windows_base_ami.value

  component {
    component_arn = aws_imagebuilder_component.windows2025_cis_harden.arn
  }

  block_device_mapping {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = var.kms_key_arn
    }
  }

  tags = var.tags
}

resource "aws_imagebuilder_infrastructure_configuration" "windows2025_cis" {
  name                          = "${var.name_prefix}-windows2025-cis"
  instance_profile_name         = var.instance_profile_name
  instance_types                = var.instance_types
  subnet_id                     = var.subnet_id
  security_group_ids            = var.security_group_ids
  terminate_instance_on_failure = true
  sns_topic_arn                 = var.sns_topic_arn

  resource_tags = merge(var.tags, {
    (var.tag_key_benchmark) = var.tag_value_windows2025
    (var.tag_key_level)     = tostring(var.cis_level)
  })

  tags = var.tags
}

resource "aws_imagebuilder_distribution_configuration" "windows2025_cis" {
  name = "${var.name_prefix}-windows2025-cis"

  distribution {
    region = data.aws_region.current.name

    ami_distribution_configuration {
      name = "${var.name_prefix}-windows2025-cis-{{ imagebuilder:buildDate }}"

      ami_tags = merge(var.tags, {
        (var.tag_key_benchmark) = var.tag_value_windows2025
        (var.tag_key_level)     = tostring(var.cis_level)
      })

      kms_key_id = var.kms_key_arn

      dynamic "launch_permission" {
        for_each = length(var.landing_zone_account_ids) > 0 ? [1] : []
        content {
          user_ids = var.landing_zone_account_ids
        }
      }
    }
  }

  dynamic "distribution" {
    for_each = toset(var.distribution_regions)
    content {
      region = distribution.value

      ami_distribution_configuration {
        name = "${var.name_prefix}-windows2025-cis-{{ imagebuilder:buildDate }}"

        ami_tags = merge(var.tags, {
          (var.tag_key_benchmark) = var.tag_value_windows2025
          (var.tag_key_level)     = tostring(var.cis_level)
        })

        dynamic "launch_permission" {
          for_each = length(var.landing_zone_account_ids) > 0 ? [1] : []
          content {
            user_ids = var.landing_zone_account_ids
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_imagebuilder_image_pipeline" "windows2025_cis" {
  name                             = "${var.name_prefix}-windows2025-cis"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.windows2025_cis.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.windows2025_cis.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.windows2025_cis.arn
  status                           = "ENABLED"

  schedule {
    schedule_expression                = var.pipeline_schedule_expression
    pipeline_execution_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
  }

  image_tests_configuration {
    image_tests_enabled = true
    timeout_minutes     = 120
  }

  tags = var.tags
}
