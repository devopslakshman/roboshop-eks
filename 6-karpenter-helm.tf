##############################################
# Karpenter Helm Release
# EKS 1.34 / Karpenter v1.6.8
##############################################

resource "helm_release" "karpenter" {

  name             = "karpenter"
  namespace        = "karpenter"
  create_namespace = true

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.6.8"

  set {
    name  = "settings.clusterName"
    value = aws_eks_cluster.cluster.name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller.arn
  }

  set {
    name  = "replicas"
    value = "2"
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  depends_on = [
    aws_eks_cluster.cluster,
    aws_eks_node_group.private-nodes,
    aws_iam_role.karpenter_controller,
    aws_iam_role_policy_attachment.karpenter_controller
  ]
}