locals {
  private_key_path = "./devops.pem"
  key_name         = "devops"
}

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

output "jenkins_ip" {
  value = aws_instance.web1.public_ip
}
