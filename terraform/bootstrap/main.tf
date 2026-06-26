terraform {
  required_version = ">= 1.10" # use_lockfile floor on the S3 backend in sibling modules

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # verify current major at session top; see prereqs
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "tfstate-demosz-rick-project"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# No DynamoDB lock table — sibling modules use Terraform 1.10's native S3
# object-lock (`use_lockfile = true` on the backend "s3" block).
# The `dynamodb_table` backend parameter is deprecated as of 1.10.
