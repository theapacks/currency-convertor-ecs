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
  tags        = merge(var.tags, {
    Name = "${aws_ecs_cluster.this.name}-alb"
  })

  # Allow HTTP traffic from anywhere (will be protected by custom headers)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP traffic (protected by CloudFront headers)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "this" {
  count              = var.enable_load_balancer ? 1 : 0
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  internal           = false  # Internet-facing for CloudFront access
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = length(var.alb_subnet_ids) > 0 ? var.alb_subnet_ids : var.subnet_ids
  tags               = merge(var.tags, {
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
  tags        = merge(var.tags, {
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

  # Default action blocks direct access
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/html"
      message_body = "<h1>Access Denied</h1><p>Direct access not allowed. Please use the CloudFront URL.</p>"
      status_code  = "403"
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
}

resource "aws_cloudfront_distribution" "this" {
  count = var.enable_load_balancer ? 1 : 0
  
  origin {
    domain_name = aws_lb.this[0].dns_name
    origin_id   = "ALB-${var.project_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Add custom header for ALB authentication
    custom_header {
      name  = "X-CloudFront-Secret"
      value = random_password.cloudfront_secret[0].result
    }
  }

  enabled = true

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ALB-${var.project_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization"]

      cookies {
        forward = "none"
      }
    }

    # Disable caching for API responses
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-cf"
  })
}