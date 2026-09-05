data "archive_file" "compliance_evaluator" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/cis-compliance-evaluator"
  output_path = "${path.module}/../../lambda/cis-compliance-evaluator.zip"
}

resource "aws_lambda_function" "compliance_evaluator" {
  function_name    = "${var.name_prefix}-compliance-evaluator"
  description      = "Generic OS-level CIS compliance evaluator: reads SSM Compliance data and reports to AWS Config. Same function backs every benchmark's Config rule — see index.py docstring."
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 256
  filename         = data.archive_file.compliance_evaluator.output_path
  source_code_hash = data.archive_file.compliance_evaluator.output_base64sha256

  tags = var.tags
}

resource "aws_lambda_permission" "allow_config" {
  statement_id  = "AllowConfigInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compliance_evaluator.function_name
  principal     = "config.amazonaws.com"
}

resource "aws_config_conformance_pack" "cis_hardening" {
  name = "${var.name_prefix}-cis-benchmarks"

  template_body = templatefile("${path.module}/templates/cis-conformance-pack.yaml.tftpl", {
    name_prefix               = var.name_prefix
    automation_document_name  = var.automation_document_name
  })

  input_parameter {
    parameter_name  = "LambdaFunctionArn"
    parameter_value = aws_lambda_function.compliance_evaluator.arn
  }
  input_parameter {
    parameter_name  = "AutomationAssumeRoleArn"
    parameter_value = var.automation_assume_role_arn
  }
  input_parameter {
    parameter_name  = "EnforceDocumentNameRhel9"
    parameter_value = var.enforce_document_name_rhel9
  }
  input_parameter {
    parameter_name  = "EnforceDocumentNameWindows2025"
    parameter_value = var.enforce_document_name_windows2025
  }
  input_parameter {
    parameter_name  = "TagKeyBenchmark"
    parameter_value = var.tag_key_benchmark
  }
  input_parameter {
    parameter_name  = "TagValueRhel9"
    parameter_value = var.tag_value_rhel9
  }
  input_parameter {
    parameter_name  = "TagValueWindows2025"
    parameter_value = var.tag_value_windows2025
  }

  depends_on = [aws_lambda_permission.allow_config]
}
