
resource "aws_cloudfront_vpc_origin" "this" {
  count = var.enable_load_balancer ? 1 : 0

  vpc_origin_endpoint_config {
    name                   = "${var.project_name}-vpc-origin"
    arn                    = aws_lb.this[0].arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  depends_on = [aws_lb.this, aws_lb_target_group.this, aws_lb_listener.this]

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc-origin"
  })

  timeouts {
    create = "20m"
  }
}

resource "aws_cloudfront_distribution" "this" {
  count = var.enable_load_balancer ? 1 : 0
  enabled = true

  origin {
    domain_name = aws_lb.this[0].dns_name
    origin_id   = "VPC-ALB-${var.project_name}"

    vpc_origin_config {
      vpc_origin_id = aws_cloudfront_vpc_origin.this[0].id
    }

    custom_header {
      name  = "X-CloudFront-Secret"
      value = random_password.cloudfront_secret[0].result
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "VPC-ALB-${var.project_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = var.cloudfront_geo_restriction.restriction_type
      locations        = var.cloudfront_geo_restriction.restriction_type == "none" ? [] : var.cloudfront_geo_restriction.locations
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  price_class = "PriceClass_200"

  tags = merge(var.tags, {
    Name = "${var.project_name}-cf"
  })
}
