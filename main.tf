
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

resource "aws_internet_gateway" "web_vpc_igw" {
  vpc_id = module.web_vpc.vpc_id

  tags = {
    Name = "web-vpc-igw"
  }
}

resource "aws_egress_only_internet_gateway" "web_vpc_egw" {
  vpc_id = module.web_vpc.vpc_id
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


resource "aws_route_table" "web_vpc" {
  vpc_id = module.web_vpc.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web_vpc_igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_egress_only_internet_gateway.web_vpc_egw.id
  }

  tags = {
    Name = "web-vpc-rt"
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
  cidr_ipv4         = module.web_vpc.vpc_cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "web_vpc_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.web_vpc_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_lb" "web_vpc_alb" {
  name               = "web-vpc-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_vpc_sg.id]
  subnets            = [aws_subnet.web_vpc_public_subnet_1_a.id, aws_subnet.web_vpc_public_subnet_1_b.id, aws_subnet.web_vpc_public_subnet_1_c.id]

  enable_deletion_protection = true

  tags = {
    Environment = "Dev"
  }
}

resource "aws_lb_target_group" "web_vpc_alb_target_group" {
  name_prefix   = "web-"
  port          = 80
  protocol      = "HTTP"
  vpc_id        = module.web_vpc.vpc_id
  target_type   = "instance"
  deregistration_delay = 300
}
