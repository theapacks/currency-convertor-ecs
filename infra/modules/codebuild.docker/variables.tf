variable "project_name" {
  description = "Project name"
  type        = string
}

variable "ecr_repository_url" {
  description = "Full ECR repository URI"
  type        = string
}

variable "dockerfile_bucket_name" {
  description = "Name of the S3 bucket to store the Dockerfile"
  type        = string
}

variable "dockerfile_key" {
  description = "S3 object key of the Dockerfile"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "codebuild_compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_image" {
  description = "Docker image for CodeBuild environment"
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
}

variable "s3_objetcs" {
  description = "Map of file names to their local file paths that will be uploaded to S3"
  type        = map(string)
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "trigger_file" {
  description = "File to trigger CodeBuild when updated"
  type        = string
  default     = "Dockerfile"
}
