
data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}


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


resource "aws_route_table" "web_vpc_rt" {
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

resource "aws_route_table_association" "web_vpc_rt_web_A__association" {
  subnet_id      = aws_subnet.web_vpc_public_subnet_1_a.id
  route_table_id = aws_route_table.web_vpc_rt.id
}

resource "aws_route_table_association" "web_vpc_rt_web_B__association" {
  subnet_id      = aws_subnet.web_vpc_public_subnet_1_b.id
  route_table_id = aws_route_table.web_vpc_rt.id
}

resource "aws_route_table_association" "web_vpc_rt_web_C__association" {
  subnet_id      = aws_subnet.web_vpc_public_subnet_1_c.id
  route_table_id = aws_route_table.web_vpc_rt.id
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
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "web_vpc_allow_all_coming_in_traffics_ipv4" {
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

  enable_deletion_protection = false

  tags = {
    Environment = "Dev"
  }
}

resource "aws_lb_target_group" "web_vpc_alb_target_group" {
  name_prefix          = "web-"
  ip_address_type      = "ipv4"
  port                 = 80
  protocol             = "HTTP"
  protocol_version     = "HTTP1"
  vpc_id               = module.web_vpc.vpc_id
  target_type          = "instance"
  deregistration_delay = 300
  health_check {
    enabled             = true
    healthy_threshold   = 5
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  stickiness {
    cookie_duration = 86400
    enabled         = false
    type            = "lb_cookie"
  }

}

resource "aws_launch_configuration" "web_launch_config" {
  name_prefix     = "learn-terraform-aws-asg-hello-horld-"
  image_id        = data.aws_ami.app_ami.id
  instance_type   = data.aws_ami.app_ami.id
  security_groups = [aws_security_group.web_vpc_sg.id]

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "web" {
  name                 = "web" 
  min_size             = 1
  max_size             = 2
  desired_capacity     = 1
  vpc_zone_identifier       = [aws_subnet.web_vpc_public_subnet_1_a.id, aws_subnet.web_vpc_public_subnet_1_b.id, aws_subnet.web_vpc_public_subnet_1_c.id]
}

resource "aws_autoscaling_attachment" "web_auto_scaling_attachment" {
  autoscaling_group_name = aws_autoscaling_group.web.id
  alb_target_group_arn   = aws_lb_target_group.web_vpc_alb_target_group.arn
}

#resource "aws_lb_target_group_attachment" "aws_lb_target_group_attachment_web" {
#  target_group_arn = aws_lb_target_group.web_vpc_alb_target_group.arn
#  target_id        = aws_instance.web.id
#  port             = 80
#}

resource "aws_lb_listener" "web_vpc_alb_listner" {
  load_balancer_arn = aws_lb.web_vpc_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_vpc_alb_target_group.arn
  }
}
