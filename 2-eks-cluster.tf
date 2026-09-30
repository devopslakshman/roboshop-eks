##############################################
# EKS Cluster IAM Role
##############################################

resource "aws_iam_role" "eks-cluster" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-eks-cluster-role"
  }
}

##############################################
# EKS Cluster Policy
##############################################

resource "aws_iam_role_policy_attachment" "amazon-eks-cluster-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster.name
}

##############################################
# EKS Cluster CloudWatch Logs
##############################################

resource "aws_cloudwatch_log_group" "eks_cluster_logs" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 1

  tags = {
    Name = "${var.cluster_name}-eks-cluster-logs"
  }
}

##############################################
# EKS Cluster
##############################################

resource "aws_eks_cluster" "cluster" {

  name    = var.cluster_name
  version = var.cluster_version

  role_arn = aws_iam_role.eks-cluster.arn

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  ############################################
  # VPC Configuration
  ############################################

  vpc_config {

    endpoint_private_access = true
    endpoint_public_access  = true

    # Public access enabled from all IPv4 addresses.
    # For production, restrict this to trusted CIDRs.
    public_access_cidrs = [
      "0.0.0.0/0"
    ]

    subnet_ids = concat(
      [aws_subnet.public.id],
      aws_subnet.private[*].id
    )

    security_group_ids = [
      aws_security_group.eks_sg.id
    ]
  }

  ############################################
  # Dependencies
  ############################################

  depends_on = [
    aws_iam_role_policy_attachment.amazon-eks-cluster-policy,
    aws_cloudwatch_log_group.eks_cluster_logs,
    aws_security_group.eks_sg
  ]

  tags = {
    Name = var.cluster_name

    "karpenter.sh/discovery" = var.cluster_name
  }
}

##############################################
# Outputs
##############################################

output "endpoint" {
  value = aws_eks_cluster.cluster.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.cluster.certificate_authority[0].data
}
