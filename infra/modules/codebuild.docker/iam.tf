resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ],
        Resource = [
          "arn:aws:s3:::${var.dockerfile_bucket_name}",
          "arn:aws:s3:::${var.dockerfile_bucket_name}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["logs:*"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "iam:PassRole"
        ],
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-task-execution-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-task-role"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "eventbridge_codebuild_role" {
  name = "${var.project_name}-eventbridge-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    { Name = "${var.project_name}-eventbridge-codebuild-role" },
    var.tags
  )

}

resource "aws_iam_policy" "eventbridge_codebuild_policy" {
  name = "${var.project_name}-eventbridge-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "codebuild:StartBuild"
        Effect   = "Allow"
        Resource = aws_codebuild_project.this.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eventbridge_codebuild_attach" {
  role       = aws_iam_role.eventbridge_codebuild_role.name
  policy_arn = aws_iam_policy.eventbridge_codebuild_policy.arn
}
