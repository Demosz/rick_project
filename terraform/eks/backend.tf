# terraform/eks/backend.tf
#
# Sibling key to ecr/terraform.tfstate in the bootstrap-created bucket.
# use_lockfile = true is the S3 native object-lock pattern from TF 1.10+;
# replaces the deprecated dynamodb_table parameter per the D18 2026-06-25
# amendment. The bootstrap workspace must have been applied before
# `terraform init` here will find the bucket.

terraform {
  backend "s3" {
    bucket       = "tfstate-demosz-rick-project"
    key          = "eks/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
