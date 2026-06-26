# terraform/ecr/backend.tf
#
# Backend points at the bucket created by terraform/bootstrap.
# Key namespaces this module's state to "ecr/terraform.tfstate" within the
# shared bucket; terraform/eks/ uses "eks/terraform.tfstate" sibling-key.

terraform {
  backend "s3" {
    bucket       = "tfstate-demosz-rick-project"
    key          = "ecr/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true # native S3 object-lock per TF 1.10+; replaces dynamodb_table
    encrypt      = true
  }
}
