output "repository_url" {
  description = "URI of the ECR repository"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.this.name

}
