
resource "aws_security_group" "vpc_endpoints" {
  count       = length(local.interface_endpoints) > 0 ? 1 : 0
  name        = "${data.aws_vpc.selected.tags.Name}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    description = "HTTPS to VPC endpoints within VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.sg_egress_cidr_blocks
  }

  tags = merge(var.tags, {
    Name = "${data.aws_vpc.selected.tags.Name}-vpc-endpoints"
  })
}

# Gateway VPC Endpoints (S3, DynamoDB)
resource "aws_vpc_endpoint" "gateway" {
  for_each = local.gateway_endpoints

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.${each.value.service}"
  vpc_endpoint_type = each.value.type
  route_table_ids   = var.route_table_ids
  policy            = each.value.policy

  tags = merge(var.tags, {
    Name = "${data.aws_vpc.selected.tags.Name}-${each.key}-endpoint"
    Type = "Gateway"
  })
}

# Interface VPC Endpoints (ECR, ECS, CloudWatch, etc.)
resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value.service}"
  vpc_endpoint_type   = each.value.type
  subnet_ids          = var.subnet_ids
  security_group_ids  = length(aws_security_group.vpc_endpoints) > 0 ? [aws_security_group.vpc_endpoints[0].id] : []
  private_dns_enabled = each.value.private_dns_enabled
  policy              = each.value.policy

  tags = merge(var.tags, {
    Name = "${data.aws_vpc.selected.tags.Name}-${each.key}-endpoint"
    Type = "Interface"
  })
}