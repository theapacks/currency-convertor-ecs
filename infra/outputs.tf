output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_name

  depends_on = [ module.ecr ]
  
}

output "ecr_repository_url" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_url

  depends_on = [ module.ecr ]
}

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id

  depends_on = [ module.vpc ]
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block

  depends_on = [ module.vpc ]
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets

  depends_on = [ module.vpc ]
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets

  depends_on = [ module.ecr ]
}

output "intra_subnets" {
  description = "List of intra subnet IDs"
  value       = module.vpc.intra_subnets

  depends_on = [ module.vpc ]
}

# VPC Endpoints Outputs
output "vpc_endpoints_count" {
  description = "Number of VPC endpoints created"
  value       = module.vpc_endpoints.endpoint_count

  depends_on = [ module.vpc_endpoints ]
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = module.vpc_endpoints.security_group_id

  depends_on = [ module.vpc_endpoints ]
}

output "vpc_endpoints_created" {
  description = "List of VPC endpoints created"
  value       = module.vpc_endpoints.vpc_endpoints

  depends_on = [ module.vpc_endpoints ]
}

output "ecr_image_info" {
  value = length(data.aws_ecr_image.image) > 0 ? {
    image_uri    = data.aws_ecr_image.image.image_uri
    image_tags   = data.aws_ecr_image.image.image_tags
    pushed_at    = data.aws_ecr_image.image.image_pushed_at
    size_bytes   = data.aws_ecr_image.image.image_size_in_bytes
  } : {
    image_uri    = "No ECR image available yet"
    image_tags   = []
    pushed_at    = 0
    size_bytes   = 0
  }

  depends_on = [data.aws_ecr_image.image]
}

# ECS Fargate Outputs

output "application_load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = module.ecs_fargate.load_balancer_dns_name

  depends_on = [ module.ecs_fargate ]
}

output "application_url" {
  description = "URL to access the application"
  value       = module.ecs_fargate.application_url

  depends_on = [ module.ecs_fargate ]
}
