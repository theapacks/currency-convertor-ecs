resource "aws_cloudwatch_log_group" "this" {
  count             = var.enable_logs ? 1 : 0
  name              = "/ecs/${aws_ecs_cluster.this.name}/${var.service_name}"
  retention_in_days = var.log_retention_in_days
  tags = merge(var.tags, {
    Name = "${aws_ecs_cluster.this.name}-${var.service_name}-log-group"
  })
}

resource "aws_security_group" "this" {
  name        = "${aws_ecs_cluster.this.name}-ecs-tasks"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id
  tags        = var.tags

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[0].id]
    description     = "Allow traffic from Application Load Balancer only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.task_definition_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  tags                     = var.tags

  container_definitions = jsonencode([
    {
      name  = var.service_name
      image = var.container_image

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        for key, value in var.environment_variables : {
          name  = key
          value = value
        }
      ]

      logConfiguration = var.enable_logs ? {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this[0].name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      } : null

      essential = true

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}