# terraform/eks/main.tf
#
# VPC + EKS cluster + managed node group. Sibling module to terraform/ecr/
# (separate state) so the cluster can be destroyed and re-created between
# learning sessions without losing ECR's image history.
#
# Cost burden: ~$250-260/mo if left running 24/7 per D19 — destroy when
# not actively learning.

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Pull the cluster's auth token at apply time. Token TTL is 15 minutes; for
# a single end-to-end apply (~15min) that's enough headroom. If the apply
# ever takes longer (e.g., debugging a helm_release timeout), swap this for
# an exec-plugin provider config that re-mints the token per call:
#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "aws"
#     args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
#   }
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# helm provider v3 switched `kubernetes` from a block to an attribute.
# v2.x syntax (`kubernetes { ... }`) is a hard error under v3 with "Blocks
# of type 'kubernetes' are not expected here." Keep the equals sign.
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name    = "rick"
  cluster_version = "1.36"
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
}

# --------------------------------------------------------------------------
# VPC — 2 AZs, public + private subnets, single NAT in the first AZ.
# Multi-AZ is forced by EKS (control-plane ENIs need ≥2 AZs); the workload
# stays single-AZ via the node group's subnet_ids below per D19.
# --------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "rick"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # D19 — second NAT is ~$33/mo of HA we don't need.
  enable_dns_hostnames = true

  # Tags for ALB controller auto-discovery of subnets.
  # `kubernetes.io/role/elb` = public ALBs; `internal-elb` = internal ALBs.
  # The controller doesn't strictly require the `cluster/<name>: shared` tag
  # at v2.x+, but we tag for explicitness and forward compat.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

# --------------------------------------------------------------------------
# EKS cluster + managed node group.
# --------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.cluster_name
  kubernetes_version = local.cluster_version

  vpc_id = module.vpc.vpc_id
  # Control plane ENIs need to land in subnets across ≥2 AZs.
  subnet_ids = module.vpc.private_subnets

  # Cluster endpoint:
  # - private = nodes reach the API server inside the VPC.
  # - public  = local `kubectl` reaches the API server over the internet,
  #             auth via IAM (no kubeconfig secrets to manage).
  # Restricting public access by CIDR is a production-realistic next step;
  # for a learning project the IAM-auth gate is enough.
  endpoint_public_access  = true
  endpoint_private_access = true

  # Authentication mode: EKS Access Entries (the 21.x default; replaces the
  # aws-auth ConfigMap shape D19 originally specified — flagging as a D19
  # deviation in the section below). Granting the apply caller cluster-admin
  # via the built-in entry rather than a manual aws-auth edit.
  enable_cluster_creator_admin_permissions = true

  # Managed addons — only the three cluster-essential ones. `eks-pod-identity-agent`
  # was dropped in the 2026-06-26 trim along with IRSA itself; `enableNetworkPolicy`
  # on vpc-cni was dropped with the D15 full reversal (no NetworkPolicy ships).
  addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    # before_compute = true installs vpc-cni BEFORE the node group is created,
    # so nodes have a CNI plugin the moment they boot. Without this flag, the
    # module creates the node group first; nodes come up but can't report
    # Healthy because there's no CNI; the node group hits CREATE_FAILED
    # (NodeCreationFailure: Unhealthy nodes in the kubernetes cluster) and
    # the apply errors out. Caught the hard way 2026-06-26.
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
  }

  # IRSA OIDC provider disabled — 2026-06-26 trim per the D4 reversal and the
  # IRSA-out call. The ALB controller's AWS permissions are attached directly
  # to the node IAM role below (every pod on the node inherits them; explicit
  # least-privilege tradeoff). No application SA needs AWS perms.
  enable_irsa = false

  # No control-plane log streams. D19 originally specified API + audit; dropped
  # 2026-06-26 along with the rest of the velocity trim. Re-enable by setting
  # `enabled_log_types = ["api", "audit"]` if forensic audit needs arise.

  eks_managed_node_groups = {
    main = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"] # D19 amended 2026-06-26: was t3.large × 2.

      # Single AZ per D19: pin the node group to the first private subnet.
      subnet_ids = [module.vpc.private_subnets[0]]

      # Single node per D19 amendment 2026-06-26 (was 2). Cuts running cost ~$60/mo;
      # loses the node-rescheduling demo (acceptable per the velocity frame).
      min_size     = 1
      max_size     = 1
      desired_size = 1

      # Two managed policies attached directly to the node IAM role:
      # - ECRReadOnly: how kubelet pulls images from terraform/ecr's repos.
      # - ALB controller policy: how the ALB controller pod calls AWS APIs to
      #   create ALBs/target groups/listeners. With IRSA out, the policy lives
      #   here — every pod on the node inherits it, which is the explicit
      #   "least-privilege I scoped out for time" interview gap.
      iam_role_additional_policies = {
        ECRReadOnly   = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        ALBController = aws_iam_policy.alb_controller.arn
      }

      # IMDSv2 enforcement (http_tokens=required) prevents SSRF-style
      # credential theft. hop_limit=2 is required so pod-network workloads
      # can reach IMDS on the host — at hop_limit=1 the response TTL hits
      # zero crossing back through the pod veth and IMDS calls time out.
      # Caught 2026-06-26 when ALB controller failed with "no EC2 IMDS
      # role found, context deadline exceeded".
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "disabled"
      }
    }
  }
}
