resource "aws_scheduler_schedule" "start-instances-schedule" {
  name       = "start-instances-schedule"
  group_name = "default"
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression = "cron(00 4 * * ? *)" # Runs at 7am every day
  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.schedule.arn

    input = jsonencode({
      "InstanceIds" : [
        aws_instance.web1.id
      ]
      }
    )
  }
}

resource "aws_scheduler_schedule" "stop-instances-schedule" {
  name       = "stop-instances-schedule"
  group_name = "default"
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression = "cron(00 16 * * ? *)" # Runs at 7pm every day
  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.schedule.arn

    input = jsonencode({
      "InstanceIds" : [
        aws_instance.web1.id
      ]
      }
    )
  }
}
