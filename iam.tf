resource "aws_iam_role" "schedule" {
  name = "iam-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "scheduler.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}
resource "aws_iam_role_policy" "stop-start-instance" {
  name = "test_policy"
  role = aws_iam_role.schedule.name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Statement1",
        "Effect" : "Allow",
        "Action" : [
          "ec2:StopInstances",
          "ec2:StartInstances"
        ],
        "Resource" : ["*"]
      }
    ]
  })
}

