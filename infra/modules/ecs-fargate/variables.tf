variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment_name" {
  description = "Name of the environment"
  type        = string
}

variable "region" {
  description = "AWS region where the resources will be deployed"
  type        = string
}

variable "capacity_provider_strategy" {
  description = "Capacity provider strategy for the ECS cluster"
  type = object({
    base   = number
    weight = number
  })
  default = {
    base   = 1
    weight = 100
  }
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "task_definition_family" {
  description = "Family name for the task definition"
  type        = string
}

variable "container_image" {
  description = "Docker image URI for the container"
  type        = string
}

variable "container_port" {
  description = "Port on which the container listens"
  type        = number
  default     = 80
}

variable "cpu" {
  description = "CPU units for the task (256, 512, 1024, etc.)"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Memory for the task in MiB"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Number of instances of the task definition to run"
  type        = number
  default     = 1
}

variable "vpc_id" {
  description = "VPC ID where the ECS service will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ECS service"
  type        = list(string)
}

variable "alb_subnet_ids" {
  description = "List of subnet IDs for the Application Load Balancer (should be public subnets)"
  type        = list(string)
  default     = []
}

variable "enable_public_ip" {
  description = "Assign a public IP to the ECS tasks"
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "Path for the health check"
  type        = string
  default     = "/health"
}

variable "health_check_port" {
  description = "Port for the health check"
  type        = string
  default     = "traffic-port"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "enable_load_balancer" {
  description = "Enable Application Load Balancer"
  type        = bool
  default     = true
}

variable "enable_logs" {
  description = "Enable CloudWatch logs"
  type        = bool
  default     = true
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}
