data "archive_file" "app" {
  type        = "zip"
  source_dir  = "${path.module}/../app/"
  output_path = "${path.module}/app.zip"

  excludes = [
    "venv",
    "__pycache__"
  ]
}

data "aws_availability_zones" "available" {}

data "aws_ecr_repository" "repo" {
  name = var.ecr_repository_name
  depends_on = [module.ecr]
}

data "aws_ecr_image" "image" {
  repository_name = var.ecr_repository_name
  most_recent     = true
  depends_on      = [module.ecr]
}