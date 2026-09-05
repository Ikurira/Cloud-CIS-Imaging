output "recipe_arn" {
  value = aws_imagebuilder_image_recipe.windows2025_cis.arn
}

output "pipeline_arn" {
  value = aws_imagebuilder_image_pipeline.windows2025_cis.arn
}

output "component_arn" {
  value = aws_imagebuilder_component.windows2025_cis_harden.arn
}

output "base_ami_id" {
  value = data.aws_ssm_parameter.windows_base_ami.value
}
