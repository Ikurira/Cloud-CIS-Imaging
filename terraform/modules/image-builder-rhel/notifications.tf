# Decoupled pipeline-completion notification: EventBridge -> SNS. No other
# module is referenced or invoked directly; anything downstream subscribes
# to the shared SNS topic (modules/shared) independently.

resource "aws_cloudwatch_event_rule" "pipeline_state_change" {
  name = "${var.name_prefix}-rhel9-cis-pipeline-state"

  event_pattern = jsonencode({
    source      = ["aws.imagebuilder"]
    detail-type = ["EC2 Image Builder Image State Change"]
    detail = {
      arn = [{ prefix = "arn:aws:imagebuilder" }]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "notify_sns" {
  rule      = aws_cloudwatch_event_rule.pipeline_state_change.name
  target_id = "sns"
  arn       = var.sns_topic_arn
}
