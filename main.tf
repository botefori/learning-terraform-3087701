
data "aws_vpc" "default" {
  default = true
}

module "web_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "web-vpc"
  cidr = "10.0.0.0/16"

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_subnet" "web_vpc_public_subnet_1_a" {
  vpc_id     = module.web_vpc.vpc_id
  cidr_block = "10.0.101.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"

  tags = {
    Name = "sn-web-1-a"
    Environment = "dev"
  }
}

resource "aws_subnet" "web_vpc_public_subnet_1_b" {
  vpc_id     = module.web_vpc.vpc_id
  cidr_block = "10.0.102.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1b"

  tags = {
    Name = "sn-web-1-b"
    Environment = "dev"
  }
}

resource "aws_subnet" "web_vpc_public_subnet_1_c" {
  vpc_id     = module.web_vpc.vpc_id
  cidr_block = "10.0.103.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1c"

  tags = {
    Name = "sn-web-1-c"
    Environment = "dev"
  }
}

resource "aws_security_group" "web_vpc_sg" {
  name        = "web-vpc-sg"
  vpc_id      = module.web_vpc.vpc_id

  tags = {
    Name = "web-vpc-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_vpc_ipv4" {
  security_group_id = aws_security_group.web_vpc_sg.id
  cidr_ipv4         = module.web_vpc.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "web_vpc_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.web_vpc_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
