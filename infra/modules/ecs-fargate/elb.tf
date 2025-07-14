# Generate random secret for CloudFront authentication
resource "random_password" "cloudfront_secret" {
  count   = var.enable_load_balancer ? 1 : 0
  length  = 32
  special = false
}

resource "aws_security_group" "alb" {
  count       = var.enable_load_balancer ? 1 : 0
  name        = "${aws_ecs_cluster.this.name}-alb"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id
  tags = merge(var.tags, {
    Name = "${aws_ecs_cluster.this.name}-alb"
  })
}

resource "aws_vpc_security_group_ingress_rule" "vpc_origin" {
  security_group_id = aws_security_group.alb[0].id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.vpc_origin.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  tags = merge(var.tags, {
    Name = "${aws_ecs_cluster.this.name}-alb-vpc-origin-ingress"
  })
}

resource "aws_vpc_security_group_egress_rule" "lb" {
  security_group_id = aws_security_group.alb[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  tags = merge(var.tags, {
    Name = "${aws_ecs_cluster.this.name}-alb-egress"
  })
}

resource "aws_lb" "this" {
  count              = var.enable_load_balancer ? 1 : 0
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  internal           = true # Internal ALB - accessible via CloudFront VPC origin
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = length(var.alb_subnet_ids) > 0 ? var.alb_subnet_ids : var.subnet_ids
  tags = merge(var.tags, {
    Name = "${var.project_name}-alb"
  })

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "this" {
  count       = var.enable_load_balancer ? 1 : 0
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  tags = merge(var.tags, {
    Name = "${var.project_name}-tg"
  })

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    port                = var.health_check_port
    protocol            = "HTTP"
    matcher             = "200"
  }
}

resource "aws_lb_listener" "this" {
  count             = var.enable_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.this[0].arn
  port              = "80"
  protocol          = "HTTP"

   default_action {
		type = "forward"
		forward {
			target_group {
				arn = aws_lb_target_group.this[0].arn
			}
		}
	}

}

# Rule to allow CloudFront traffic with custom header
resource "aws_lb_listener_rule" "cloudfront_access" {
  count        = var.enable_load_balancer ? 1 : 0
  listener_arn = aws_lb_listener.this[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  condition {
    http_header {
      http_header_name = "X-CloudFront-Secret"
      values           = [random_password.cloudfront_secret[0].result]
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-cloudfront-access-rule"
  })
}
