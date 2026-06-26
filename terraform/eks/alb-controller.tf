# terraform/eks/alb-controller.tf
#
# AWS Load Balancer Controller — installed via helm_release into kube-system.
# The controller watches Ingress and Service resources and provisions ALBs/NLBs
# in AWS to satisfy them. No ALB exists until 5.4 creates an Ingress.
#
# Permissions wiring (post-2026-06-26 trim, IRSA dropped):
# - Canonical IAM policy JSON is fetched from the upstream repo at plan time.
# - Created as a standalone aws_iam_policy resource here.
# - Attached to the node IAM role in main.tf via iam_role_additional_policies.
# - Every pod on the node inherits the policy — the explicit least-privilege
#   gap. Production answer is "use IRSA"; here it's scoped out.

data "http" "alb_controller_policy" {
  # Pinned to the chart's appVersion (v3.4.0). Bumping the chart pin in the
  # helm_release block below means bumping this URL in lockstep. If the
  # response_body is rejected by aws_iam_policy with "not a JSON object",
  # the tag in this URL probably doesn't exist on the upstream repo
  # (GitHub returns an HTML 404 page) — verify the tag with
  # `gh repo clone kubernetes-sigs/aws-load-balancer-controller && git tag | grep v`.
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.4.0/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller" {
  name        = "rick-alb-controller"
  description = "Permissions for the AWS Load Balancer Controller pod. Attached to the EKS node IAM role (IRSA scoped out)."
  policy      = data.http.alb_controller_policy.response_body
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  # helm-provider v3 dropped support for constraint expressions on chart
  # version — `~> 3.0` errors with "Planned version is different from
  # configured version". Pin exactly. Lockstep with the iam_policy.json URL
  # above (which points at the matching upstream controller tag).
  version   = "3.4.0"
  namespace = "kube-system"

  # Wait for the controller's pods to be Ready before declaring success.
  # Without this, terraform apply succeeds the moment Helm posts the manifest;
  # a downstream Ingress in 5.4 could race the controller's actual readiness.
  wait    = true
  timeout = 600

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name

      # region + vpcId are passed explicitly because the controller's default
      # autodiscovery hits EC2 Instance Metadata Service (IMDS) which is
      # blocked from pods by the EC2 default hop-limit of 1. Without these
      # values the controller crashloops with "failed to introspect region
      # from EC2Metadata: context deadline exceeded". Proper fix is to raise
      # the node group's IMDS hop limit to 2; passing region/vpcId in chart
      # values is the velocity workaround. Caught the hard way 2026-06-26.
      region = "us-east-1"
      vpcId  = module.vpc.vpc_id

      # Single replica — chart-v3 default is 2, but the 1-node t3.medium
      # cluster can't honor podAntiAffinity for two controller replicas
      # (one would stay Pending forever). 2026-06-26 D19 amendment.
      replicaCount = 1

      # No serviceAccount.annotations block — IRSA was dropped 2026-06-26.
      # The chart still creates a kube-system SA named
      # `aws-load-balancer-controller` (chart default); the pod's AWS API
      # calls authenticate via the node IAM role's attached policy instead
      # of via an SA-bound IAM role.
    })
  ]

  depends_on = [module.eks]
}
