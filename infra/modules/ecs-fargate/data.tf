data "aws_region" "current" {}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ec2_managed_prefix_list" "vpc_origin" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}
