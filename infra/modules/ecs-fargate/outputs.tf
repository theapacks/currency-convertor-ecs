output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.this.arn
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Family of the task definition"
  value       = aws_ecs_task_definition.this.family
}

output "task_definition_revision" {
  description = "Revision of the task definition"
  value       = aws_ecs_task_definition.this.revision
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = var.enable_load_balancer ? aws_lb.this[0].dns_name : null
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = var.enable_load_balancer ? aws_lb.this[0].zone_id : null
}

output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = var.enable_load_balancer ? aws_lb.this[0].arn : null
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = var.enable_load_balancer ? aws_lb_target_group.this[0].arn : null
}

output "security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.this.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = var.enable_load_balancer ? aws_security_group.alb[0].id : null
}

output "task_execution_role_arn" {
  description = "ARN of the task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "task_role_arn" {
  description = "ARN of the task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = var.enable_logs ? aws_cloudwatch_log_group.this[0].name : null
}

output "application_url" {
  description = "Primary HTTPS URL to access the application via CloudFront"
  value       = var.enable_load_balancer ? "https://${aws_cloudfront_distribution.this[0].domain_name}" : null
}

output "alb_dns_name" {
  description = "DNS name of the ALB (direct access blocked)"
  value       = var.enable_load_balancer ? aws_lb.this[0].dns_name : null
  sensitive   = true
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name for the application"
  value       = var.enable_load_balancer ? aws_cloudfront_distribution.this[0].domain_name : null
}


