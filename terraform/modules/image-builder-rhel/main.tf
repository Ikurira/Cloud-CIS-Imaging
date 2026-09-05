data "aws_region" "current" {}

data "aws_ami" "rhel9_base" {
  most_recent = true
  owners      = [var.base_ami_owner]

  filter {
    name   = "name"
    values = [var.base_ami_name_pattern]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_imagebuilder_component" "rhel9_cis_harden" {
  name        = "${var.name_prefix}-rhel9-cis-harden"
  description = "Native (no Ansible) CIS RHEL9 hardening: build-time remediate + validate."
  platform    = "Linux"
  version     = "1.0.0"

  data = templatefile("${path.module}/component.yaml.tftpl", {
    artifact_parameter_name = var.artifact_parameter_name
    region                  = data.aws_region.current.name
    cis_level               = var.cis_level
    cis_profile             = var.cis_profile
  })

  tags = var.tags
}

resource "aws_imagebuilder_image_recipe" "rhel9_cis" {
  name         = "${var.name_prefix}-rhel9-cis"
  version      = "1.0.0"
  parent_image = data.aws_ami.rhel9_base.id

  component {
    component_arn = aws_imagebuilder_component.rhel9_cis_harden.arn
  }

  block_device_mapping {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = var.kms_key_arn
    }
  }

  tags = var.tags
}

resource "aws_imagebuilder_infrastructure_configuration" "rhel9_cis" {
  name                          = "${var.name_prefix}-rhel9-cis"
  instance_profile_name         = var.instance_profile_name
  instance_types                = var.instance_types
  subnet_id                     = var.subnet_id
  security_group_ids            = var.security_group_ids
  terminate_instance_on_failure = true
  sns_topic_arn                 = var.sns_topic_arn

  resource_tags = merge(var.tags, {
    (var.tag_key_benchmark) = var.tag_value_rhel9
    (var.tag_key_level)     = tostring(var.cis_level)
  })

  tags = var.tags
}

resource "aws_imagebuilder_distribution_configuration" "rhel9_cis" {
  name = "${var.name_prefix}-rhel9-cis"

  distribution {
    region = data.aws_region.current.name

    ami_distribution_configuration {
      name = "${var.name_prefix}-rhel9-cis-{{ imagebuilder:buildDate }}"

      ami_tags = merge(var.tags, {
        (var.tag_key_benchmark) = var.tag_value_rhel9
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
        name = "${var.name_prefix}-rhel9-cis-{{ imagebuilder:buildDate }}"

        ami_tags = merge(var.tags, {
          (var.tag_key_benchmark) = var.tag_value_rhel9
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

resource "aws_imagebuilder_image_pipeline" "rhel9_cis" {
  name                             = "${var.name_prefix}-rhel9-cis"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.rhel9_cis.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.rhel9_cis.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.rhel9_cis.arn
  status                           = "ENABLED"

  schedule {
    schedule_expression                = var.pipeline_schedule_expression
    pipeline_execution_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
  }

  image_tests_configuration {
    image_tests_enabled = true
    timeout_minutes     = 90
  }

  tags = var.tags
}
