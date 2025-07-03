variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
}

variable "environment_name" {
  description = "The name of the environment"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "aws_profile" {
  description = "AWS cli profile"
  type        = string
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "currency-convertor-api"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project = "currency-convertor"
  }
}
