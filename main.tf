### VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block           = local.cidr_block
  enable_dns_support   = "true" #give u an internal domain name
  enable_dns_hostnames = "true" #give u an internal host name
  instance_tenancy     = "default"
  tags = {
    Name = "prod-vpc"
  }
}

resource "aws_subnet" "prod-subnet-public-1" {
  vpc_id                  = aws_vpc.prod-vpc.id
  cidr_block              = local.public_subnets_cidr_block
  map_public_ip_on_launch = "true" #make the subnet public
  availability_zone       = "eu-west-1a"
  tags = {
    Name = "prod-subnet-public-1"
  }
}

resource "aws_internet_gateway" "prod-igw" {
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
    Name = "prod-igw"
  }
}

resource "aws_route_table" "prod-public-rt" {
  vpc_id = aws_vpc.prod-vpc.id
  route {
    //associated subnet can reach everywhere
    cidr_block = local.cidr_block
    //rt uses this IGW to reach the internet 
    gateway_id = aws_internet_gateway.prod-igw.id
  }
  tags = {
    Name = "prod-public-rt"
  }
}

resource "aws_route_table_association" "prod-rta-public-subnet-1" {
  subnet_id      = aws_subnet.prod-subnet-public-1.id
  route_table_id = aws_route_table.prod-public-rt.id
}

resource "aws_security_group" "ssh-allowed" {
  name   = "${local.name} Security Group"
  vpc_id = aws_vpc.prod-vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.security_access
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.security_access
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = local.security_access
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = local.security_access
  }
  tags = {
    Name = "ssh-allowed"
  }
}

###EC2
resource "tls_private_key" "demo_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.demo_key.public_key_openssh
}

resource "local_file" "ssh_key" {
  filename        = "${local.key_name}.pem"
  content         = tls_private_key.demo_key.private_key_pem
  file_permission = "0400"
}

resource "aws_instance" "web1" {
  ami                         = lookup(var.AMI, var.AWS_REGION)
  subnet_id                   = aws_subnet.prod-subnet-public-1.id
  instance_type               = var.ec2_instance_type
  associate_public_ip_address = true
  key_name                    = local.key_name
  vpc_security_group_ids      = [aws_security_group.ssh-allowed.id]

  provisioner "remote-exec" {
    inline = ["echo 'Wait untill SSH is ready'"]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = local_file.ssh_key.content
      host        = self.public_ip
    }
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${self.public_ip}, --private-key ${local.private_key_path} jenkins.yaml"
  }
}

###EVENTBRIDGE
resource "aws_scheduler_schedule" "start-instances-schedule" {
  name       = "start-instances-schedule"
  group_name = "default"
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression = local.time_instance_start
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
  schedule_expression = local.time_instance_stop
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

###SNS
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
  endpoint  = local.email_usr
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

###IAM
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




