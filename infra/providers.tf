terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.7.1"
    }
  }
  #TODO: add S3 backend
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "archive" {
}
