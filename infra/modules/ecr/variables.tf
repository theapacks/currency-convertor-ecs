variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the repository"
  type        = map(string)
}

variable "kms_key_id" {
  description = "The KMS key ID to use for ECR repository encryption"
  type        = string
  default     = null
}
