##############################################
# Karpenter EC2NodeClass
# EKS 1.34 / Karpenter v1.x
##############################################

resource "kubectl_manifest" "karpenter_ec2_node_class" {

  depends_on = [
    aws_eks_cluster.cluster,
    aws_eks_node_group.private-nodes,
    helm_release.karpenter,
    aws_iam_role.karpenter_node
  ]

  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass

    metadata:
      name: default

    spec:

      amiSelectorTerms:
        - alias: al2023@latest

      role: ${aws_iam_role.karpenter_node.name}

      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}

      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}

      tags:
        Name: ${var.cluster_name}-karpenter-node
        cluster: ${var.cluster_name}
        karpenter.sh/discovery: ${var.cluster_name}
        created_by: terraform
  YAML
}


##############################################
# Karpenter NodePool
##############################################

resource "kubectl_manifest" "karpenter_node_pool" {

  depends_on = [
    kubectl_manifest.karpenter_ec2_node_class
  ]

  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool

    metadata:
      name: default

    spec:

      limits:
        cpu: "100"

      template:

        metadata:
          labels:
            workload: karpenter

        spec:

          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default

          requirements:

            - key: kubernetes.io/arch
              operator: In
              values:
                - amd64

            - key: kubernetes.io/os
              operator: In
              values:
                - linux

            - key: karpenter.sh/capacity-type
              operator: In
              values:
                - on-demand

            - key: karpenter.k8s.aws/instance-category
              operator: In
              values:
                - t

            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values:
                - "2"

          expireAfter: 720h

      disruption:

        consolidationPolicy: WhenEmptyOrUnderutilized

        consolidateAfter: 1m
  YAML
}