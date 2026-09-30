##############################################
# Karpenter Controller IAM Role
# EKS 1.34 / Karpenter v1.x
##############################################

data "aws_iam_policy_document" "karpenter_controller_assume_role_policy" {

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
        "system:serviceaccount:karpenter:karpenter"
      ]
    }
  }
}


##############################################
# Controller IAM Role
##############################################

resource "aws_iam_role" "karpenter_controller" {

  name = "${var.cluster_name}-eks-karpenter-controller"

  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume_role_policy.json

  tags = {
    Name       = "${var.cluster_name}-karpenter-controller-role"
    cluster    = var.cluster_name
    created_by = "terraform"
  }

  depends_on = [
    aws_iam_openid_connect_provider.eks
  ]
}


##############################################
# Controller IAM Policy
##############################################

resource "aws_iam_policy" "karpenter_controller" {

  name = "${var.cluster_name_in_camelcase}KarpenterController"

  description = "IAM policy for Karpenter controller"

  policy = file("${path.module}/controller-trust-policy.json")

  tags = {
    Name       = "${var.cluster_name}-karpenter-controller-policy"
    cluster    = var.cluster_name
    created_by = "terraform"
  }

  depends_on = [
    aws_iam_role.karpenter_controller
  ]
}


##############################################
# Attach Controller Policy
##############################################

resource "aws_iam_role_policy_attachment" "karpenter_controller" {

  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn

  depends_on = [
    aws_iam_policy.karpenter_controller
  ]
}