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