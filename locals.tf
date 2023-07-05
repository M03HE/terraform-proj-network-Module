locals {
  ###VPC
  name                      = var.name
  cidr_block                = var.vpc_cidr_block
  public_subnets_cidr_block = var.public_subnets_cidr_block
  security_access           = var.security_access
  ###EC2
  private_key_path    = "./devops.pem"
  key_name            = "devops"
  time_instance_stop  = var.time_instance_stop
  time_instance_start = var.time_instance_start
  ###SNS
  email_usr   = var.email_usr
}
