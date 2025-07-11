resource "aws_codebuild_project" "this" {
  name          = "${var.project_name}-codebuild-docker"
  description   = "Builds Docker image from S3 source triggered by Dockerfile change"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "10" # minutes

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = var.codebuild_compute_type
    image           = var.codebuild_image
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
      type  = "PLAINTEXT"
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.region
      type  = "PLAINTEXT"
    }
    environment_variable {
      name  = "ECR_REPOSITORY_NAME"
      value = var.ecr_repository_name
      type  = "PLAINTEXT"
    }
    environment_variable {
      name  = "DOCKERFILE_BUCKET"
      value = var.dockerfile_bucket_name
      type  = "PLAINTEXT"
    }
    environment_variable {
      name  = "DOCKERFILE_KEY"
      value = var.dockerfile_key
      type  = "PLAINTEXT"
    }
    environment_variable {
      name  = "ECS_CLUSTER_NAME"
      value = var.ecs_cluster_name
      type  = "PLAINTEXT"
    }
    environment_variable {
      name  = "ECS_SERVICE_NAME"
      value = var.ecs_service_name
      type  = "PLAINTEXT"
    }

  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}"
      stream_name = "build"
      status      = "ENABLED"
    }
  }

  source {
    type      = "S3"
    location  = "${aws_s3_bucket.this.bucket}/"
    buildspec = contains(keys(var.s3_objetcs), "buildspec.yml") ? aws_s3_object.files["buildspec.yml"].key : "buildspec.yml"
  }

  source_version = "" # Use latest version from S3 location


  tags = merge(
    var.tags,
    { Name = "${var.project_name}-codebuild-docker" }
  )

  depends_on = [
    aws_s3_object.files
  ]
}

resource "aws_s3_bucket_notification" "this" {
  bucket = aws_s3_bucket.this.id

  eventbridge = true

  depends_on = [aws_codebuild_project.this]
}

resource "aws_cloudwatch_event_target" "codebuild_target" {
  rule           = aws_cloudwatch_event_rule.s3_dockerfile_trigger.name
  event_bus_name = aws_cloudwatch_event_rule.s3_dockerfile_trigger.event_bus_name
  arn            = aws_codebuild_project.this.arn
  role_arn       = aws_iam_role.eventbridge_codebuild_role.arn
}
