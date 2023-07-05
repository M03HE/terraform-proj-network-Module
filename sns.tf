resource "aws_cloudwatch_event_rule" "ec2-alert" {
  name        = "capture-aws-ec2"
  description = "Capture each AWS ec2 stop and running"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["stopped", "running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.ec2-alert.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.aws_logins.arn
}

resource "aws_sns_topic" "aws_logins" {
  name = "aws-console-logins"
}

resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.aws_logins.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

resource "aws_sns_topic_subscription" "email-target" {
  topic_arn = aws_sns_topic.aws_logins.arn
  protocol  = "email"
  endpoint  = "moshemhd@gmail.com"
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.aws_logins.arn]
  }
}
