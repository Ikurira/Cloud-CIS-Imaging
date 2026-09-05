output "recipe_arn" {
  value = aws_imagebuilder_image_recipe.rhel9_cis.arn
}

output "pipeline_arn" {
  value = aws_imagebuilder_image_pipeline.rhel9_cis.arn
}

output "component_arn" {
  value = aws_imagebuilder_component.rhel9_cis_harden.arn
}

output "base_ami_id" {
  value = data.aws_ami.rhel9_base.id
}
