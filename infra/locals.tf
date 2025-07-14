locals {
  # Network configuration
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  # Container image for initial deployment
  # Uses Alpine as a lightweight bootstrap image - CodeBuild will update with actual app image
  # Alternative: Use ECR URL directly if repository already exists
  container_image = "public.ecr.aws/docker/library/alpine:latest"

  # Common tags applied to all resources
  tags = merge(var.tags, {
    Environment = var.environment_name
    Project     = var.project_name
  })
}