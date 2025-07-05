resource "aws_s3_bucket" "this" {
  bucket        = var.dockerfile_bucket_name
  force_destroy = true

  tags = merge(
    {
      Name = var.dockerfile_bucket_name
    },
    var.tags
  )
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  restrict_public_buckets = true
  ignore_public_acls      = true
  block_public_policy     = true
  block_public_acls       = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "files" {
  for_each = var.s3_objetcs

  bucket = aws_s3_bucket.this.id
  key    = each.key
  source = each.value
  etag   = filemd5(each.value)
  tags = merge(
    var.tags,
    {
      Name = each.key
    }
  )
}

resource "aws_cloudwatch_event_rule" "s3_dockerfile_trigger" {
  name        = "${var.project_name}-dockerfile-trigger"
  description = "Triggers CodeBuild when Dockerfile is updated in S3"

  event_pattern = jsonencode({
    "source" : ["aws.s3"],
    "detail-type" : ["Object Created"], # Catches PUT, POST, COPY that create/overwrite
    "detail" : {
      "bucket" : {
        "name" : [aws_s3_bucket.this.bucket]
      },
      "object" : {
        "key" : [var.trigger_file]
      }
    }
  })

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-dockerfile-trigger" }
  )

  depends_on = [
    aws_s3_bucket_notification.this
  ]
}
