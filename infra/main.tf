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

  s3_objetcs = {
    "buildspec.yml" = "./buildspec.yml"
    "app.zip"       = data.archive_file.app.output_path
  }

  trigger_file = "app.zip"

  depends_on = [module.ecr]
}

