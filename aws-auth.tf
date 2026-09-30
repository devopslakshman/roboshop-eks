##############################################
# EKS aws-auth ConfigMap
##############################################

resource "kubectl_manifest" "aws_auth" {
  depends_on = [
    aws_eks_cluster.cluster,
    aws_eks_node_group.private-nodes,
    aws_iam_role.karpenter_node
  ]

  yaml_body = yamlencode({
    apiVersion = "v1"

    kind = "ConfigMap"

    metadata = {
      name      = "aws-auth"
      namespace = "kube-system"
    }

    data = {
      mapRoles = yamlencode([
        {
          rolearn  = aws_iam_role.nodes.arn
          username = "system:node:{{EC2PrivateDNSName}}"

          groups = [
            "system:bootstrappers",
            "system:nodes"
          ]
        },
        {
          rolearn  = aws_iam_role.karpenter_node.arn
          username = "system:node:{{EC2PrivateDNSName}}"

          groups = [
            "system:bootstrappers",
            "system:nodes"
          ]
        }
      ])
    }
  })
}
