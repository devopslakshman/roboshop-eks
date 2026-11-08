
##############################################
# EFS CSI Driver - IAM Trust Policy
##############################################

data "aws_iam_policy_document" "efs_csi_assume_role" {

  statement {
    effect = "Allow"

    actions = ["sts:AssumeRoleWithWebIdentity"]

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
      )}:sub"

      values = [
        "system:serviceaccount:kube-system:efs-csi-controller-sa"
      ]
    }

    condition {
      test = "StringEquals"

      variable = "${replace(
        aws_iam_openid_connect_provider.eks.url,
        "https://",
        ""
      )}:aud"

      values = ["sts.amazonaws.com"]
    }
  }
}

##############################################
# EFS CSI Driver IAM Role
##############################################

resource "aws_iam_role" "efs_csi_role" {

  name = "${var.cluster_name}-EFS-CSI-Role"

  assume_role_policy = data.aws_iam_policy_document.efs_csi_assume_role.json

  tags = {
    Name       = "${var.cluster_name}-EFS-CSI-Role"
    created_by = "terraform"
  }
}

##############################################
# EFS CSI Driver IAM Policy
##############################################

resource "aws_iam_role_policy_attachment" "efs_csi_policy" {

  role = aws_iam_role.efs_csi_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

##############################################
# EFS CSI Driver EKS Add-on
##############################################

resource "aws_eks_addon" "efs_csi" {

  cluster_name = aws_eks_cluster.cluster.name

  addon_name = "aws-efs-csi-driver"

  service_account_role_arn = aws_iam_role.efs_csi_role.arn

  depends_on = [
    aws_iam_role_policy_attachment.efs_csi_policy,
    aws_eks_node_group.private-nodes
  ]
}
