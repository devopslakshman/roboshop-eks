
##############################################
# AWS Load Balancer Controller
# Roboshop EKS Cluster
# EKS 1.34
##############################################

##############################################
# Download IAM Policy
##############################################

data "http" "lbc_iam_policy" {

  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json"

  request_headers = {
    Accept = "application/json"
  }
}


##############################################
# Create IAM Policy
##############################################

resource "aws_iam_policy" "lbc" {

  name        = "${var.cluster_name}-AWSLoadBalancerControllerPolicy"
  description = "IAM permissions for AWS Load Balancer Controller"

  policy = data.http.lbc_iam_policy.response_body

  tags = {
    Name       = "${var.cluster_name}-AWSLoadBalancerControllerPolicy"
    cluster    = var.cluster_name
    created_by = "terraform"
  }
}


##############################################
# OIDC Assume Role Policy
# Reuse Existing EKS OIDC Provider
##############################################

data "aws_iam_policy_document" "lbc_assume_role" {

  statement {

    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.eks.arn
      ]
    }

    condition {

      test = "StringEquals"

      variable = "${replace(
        aws_iam_openid_connect_provider.eks.url,
        "https://",
        ""
      )}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {

      test = "StringEquals"

      variable = "${replace(
        aws_iam_openid_connect_provider.eks.url,
        "https://",
        ""
      )}:sub"

      values = [
        "system:serviceaccount:kube-system:aws-load-balancer-controller"
      ]
    }
  }
}


##############################################
# Create IAM Role
##############################################

resource "aws_iam_role" "lbc" {

  name = "${var.cluster_name}-aws-load-balancer-controller-role"

  assume_role_policy = data.aws_iam_policy_document.lbc_assume_role.json

  tags = {
    Name       = "${var.cluster_name}-aws-load-balancer-controller-role"
    cluster    = var.cluster_name
    created_by = "terraform"
  }

  depends_on = [
    aws_iam_openid_connect_provider.eks
  ]
}


##############################################
# Attach IAM Policy to Role
##############################################

resource "aws_iam_role_policy_attachment" "lbc" {

  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}


##############################################
# Create Kubernetes ServiceAccount
##############################################

resource "kubectl_manifest" "lbc_service_account" {

  yaml_body = <<-YAML
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: aws-load-balancer-controller
      namespace: kube-system
      annotations:
        eks.amazonaws.com/role-arn: ${aws_iam_role.lbc.arn}
  YAML

  depends_on = [
    aws_iam_role_policy_attachment.lbc,
    aws_eks_cluster.cluster
  ]
}


##############################################
# Install AWS Load Balancer Controller
# Using Helm
##############################################

resource "helm_release" "lbc" {

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  version = "1.14.0"

  create_namespace = false

  ############################################
  # EKS Cluster Name
  ############################################

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  ############################################
  # AWS Region
  ############################################

  set {
    name  = "region"
    value = var.aws_region
  }

  ############################################
  # VPC ID
  ############################################

  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }

  ############################################
  # ServiceAccount Configuration
  ############################################

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  ############################################
  # Dependencies
  ############################################

  depends_on = [
    kubectl_manifest.lbc_service_account,
    aws_iam_role_policy_attachment.lbc,
    aws_eks_cluster.cluster
  ]
}


##############################################
# Outputs
##############################################

output "lbc_iam_role_arn" {

  description = "IAM Role ARN for AWS Load Balancer Controller"

  value = aws_iam_role.lbc.arn
}


output "lbc_helm_release_status" {

  description = "Helm release status for AWS Load Balancer Controller"

  value = helm_release.lbc.status
}
