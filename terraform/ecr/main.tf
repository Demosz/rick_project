# terraform/ecr/main.tf
#
# ECR repos for the web and rules-service images.
# Sibling to terraform/eks/ — separate state file in the same backend bucket
# so the cluster can be ephemeral while the registry persists across
# `terraform destroy` cycles. Interview defense: clusters are cattle,
# registries are pets.

terraform {
  required_version = ">= 1.10" # use_lockfile floor on the S3 backend

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # match bootstrap; bump in lockstep
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  repos = ["web", "rules-service"]
}

resource "aws_ecr_repository" "this" {
  for_each = toset(local.repos)

  name = each.value

  # IMMUTABLE: once :v0.1.0 is pushed, it can't be overwritten by re-push.
  # Production-realistic; the cost is that 5.2 has to bump the version tag
  # if you ever need to re-push corrected content.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    # AWS's native ECR scanner (no extra cost for basic scans). Runs on push.
    # Findings surface in the ECR console + via `aws ecr describe-image-scan-findings`.
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  # Allow `terraform destroy` even when the repo still contains images.
  # Without force_delete, destroy fails if there are any tagged images,
  # which makes dev-time teardown awkward.
  force_delete = true
}

output "repository_urls" {
  description = "Map of repo name -> full ECR URI; 5.2's tag-and-push consumes these."
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}
