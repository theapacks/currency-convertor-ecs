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

# ECS Configuration
variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "currency-convertor-cluster"
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = "currency-convertor-service"
}

variable "ecs_task_cpu" {
  description = "CPU units for the ECS task"
  type        = string
  default     = "256"
}

variable "ecs_task_memory" {
  description = "Memory for the ECS task in MiB"
  type        = string
  default     = "512"
}

variable "ecs_desired_count" {
  description = "Number of ECS task instances to run"
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Port on which the container listens"
  type        = number
  default     = 8080
}
