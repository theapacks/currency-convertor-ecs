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

data "aws_ip_ranges" "cloudfront" {
  regions  = ["global"]
  services = ["cloudfront"]
}