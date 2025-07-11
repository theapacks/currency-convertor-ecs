resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-${var.environment_name}-ecs-cluster"

}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = var.capacity_provider_strategy.base
    weight            = var.capacity_provider_strategy.weight
    capacity_provider = "FARGATE"
  }

}