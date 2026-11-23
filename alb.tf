
##############################################
# Existing Application Load Balancer
##############################################

resource "aws_lb" "main" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.allow_all.id
  ]

  subnets = [
    aws_subnet.public.id,
    aws_subnet.public_b.id,
    aws_subnet.public_c.id
  ]

  enable_deletion_protection = false

  tags = {
    Name        = "${var.cluster_name}-alb"
    environment = var.environment
    created_by  = "terraform"
  }
}

##############################################
# NGINX Ingress Target Group
##############################################

resource "aws_lb_target_group" "app1" {
  name     = "roboshop-app1-tg"
  port     = 30080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # EKS worker node targets
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/healthz"
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "roboshop-nginx-ingress-tg"
    Environment = var.environment
    Project     = "roboshop"
    CreatedBy   = "Terraform"
  }
}

##############################################
# Existing ALB HTTP Listener
##############################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app1.arn
  }
}

##############################################
# ALB DNS Output
##############################################

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

##############################################
# ALB ARN Output
##############################################

output "alb_arn" {
  value = aws_lb.main.arn
}

##############################################
# Target Group ARN Output
##############################################

output "app1_target_group_arn" {
  value = aws_lb_target_group.app1.arn
}
