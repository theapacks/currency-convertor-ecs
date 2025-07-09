data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_iam_policy_document" "endpoint_policy" {
  statement {
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpc"

      values = [var.vpc_id]
    }
  }
}