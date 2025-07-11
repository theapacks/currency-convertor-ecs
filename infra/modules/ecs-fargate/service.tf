resource "aws_ecs_service" "this" {
  name            = "${aws_ecs_cluster.this.name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"


  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = var.enable_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.enable_load_balancer ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  tags = merge(var.tags, {
    Name = "${aws_ecs_cluster.this.name}-${var.service_name}-service"
  })

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [
    aws_lb_listener.this
  ]
}
