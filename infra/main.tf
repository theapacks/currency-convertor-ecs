module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.ecr_repository_name
  tags            = var.tags
}

module "codebuild_docker" {
  source                 = "./modules/codebuild.docker"
  project_name           = var.project_name
  ecr_repository_url     = module.ecr.repository_url
  ecr_repository_name    = module.ecr.repository_name
  dockerfile_bucket_name = "${var.project_name}-dockerfile-${var.environment_name}"
  dockerfile_key         = "app.zip"
  aws_region             = var.aws_region
  codebuild_compute_type = "BUILD_GENERAL1_SMALL"
  codebuild_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
  tags                   = var.tags

  # ECS deployment configuration
  ecs_cluster_name = module.ecs_fargate.cluster_name
  ecs_service_name = module.ecs_fargate.service_name

  s3_objetcs = {
    "buildspec.yml" = "./buildspec.yml"
    "app.zip"       = data.archive_file.app.output_path
  }

  trigger_file = "app.zip"

  depends_on = [module.ecr]
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.project_name}-${var.environment_name}-vpc"
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for key, value in local.azs : cidrsubnet(local.vpc_cidr, 8, key)]
  public_subnets  = [for key, value in local.azs : cidrsubnet(local.vpc_cidr, 8, key + 4)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 20)]

  create_database_subnet_group  = false
  manage_default_network_acl    = false
  manage_default_route_table    = false
  manage_default_security_group = false

  vpc_flow_log_iam_role_name            = "${var.project_name}-${var.environment_name}-vpc-flow-log-role"
  vpc_flow_log_iam_role_use_name_prefix = false
  enable_flow_log                       = true
  create_flow_log_cloudwatch_log_group  = true
  create_flow_log_cloudwatch_iam_role   = true
  flow_log_max_aggregation_interval     = 60

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  vpc_id     = module.vpc.vpc_id
  region     = var.aws_region
  subnet_ids = module.vpc.private_subnets
  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids
  )

  endpoints = {
    s3 = {
      service = "s3"
      type    = "Gateway"
    }

    ecr-api = {
      service = "ecr.api"
      type    = "Interface"
    }
    ecr-dkr = {
      service = "ecr.dkr"
      type    = "Interface"
    }
    ecs = {
      service = "ecs"
      type    = "Interface"
    }
    ecs-telemetry = {
      service = "ecs-telemetry"
      type    = "Interface"
    }
    logs = {
      service = "logs"
      type    = "Interface"
    }
    monitoring = {
      service = "monitoring"
      type    = "Interface"
    }
    ssm = {
      service = "ssm"
      type    = "Interface"
    }
    kms = {
      service = "kms"
      type    = "Interface"
    }
    secretsmanager = {
      service = "secretsmanager"
      type    = "Interface"
    }
  }

  tags = local.tags

  depends_on = [module.vpc]
}

module "ecs_fargate" {
  source = "./modules/ecs-fargate"

  project_name           = var.project_name
  environment_name       = var.environment_name
  region                 = var.aws_region
  service_name           = var.ecs_service_name
  task_definition_family = "${var.project_name}-${var.environment_name}-task"

  # Use the ECR repository URL with a dynamic tag
  container_image = local.container_image
  container_port  = var.container_port

  cpu           = var.ecs_task_cpu
  memory        = var.ecs_task_memory
  desired_count = var.ecs_desired_count

  # VPC Configuration
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  alb_subnet_ids = module.vpc.public_subnets

  # Since we're using private subnets, disable public IP
  enable_public_ip = false

  # Load balancer configuration
  enable_load_balancer = true

  # Logging configuration
  enable_logs           = true
  log_retention_in_days = 7

  # Health check configuration
  health_check_path = "/health"

  # Environment variables for the container
  environment_variables = {
    AWS_DEFAULT_REGION = var.aws_region
    ENVIRONMENT        = var.environment_name
    PROJECT_NAME       = var.project_name
  }

  tags = local.tags

  depends_on = [
    module.vpc,
    module.vpc_endpoints,
    module.ecr
  ]
}

resource "null_resource" "trigger_initial_build" {
  triggers = {
    cluster_arn = module.ecs_fargate.cluster_arn
    service_arn = module.ecs_fargate.service_arn
    app_hash    = data.archive_file.app.output_md5
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Triggering initial CodeBuild after ECS cluster is ready..."
      aws codebuild start-build \
        --project-name ${module.codebuild_docker.build_project_name} \
        --region ${var.aws_region} \
        --profile ${var.aws_profile}
    EOT
  }

  depends_on = [
    module.ecs_fargate,
    module.codebuild_docker
  ]
}
