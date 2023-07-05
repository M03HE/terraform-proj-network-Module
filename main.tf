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
