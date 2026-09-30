##############################################
# EKS Managed Node Group IAM Role
##############################################

resource "aws_iam_role" "nodes" {

  name = "${var.cluster_name}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name       = "${var.cluster_name}-eks-node-group-role"
    cluster    = var.cluster_name
    created_by = "terraform"
  }
}


##############################################
# CloudWatch Policy for EKS Nodes
##############################################

resource "aws_iam_policy" "amazon-eks-worker-node-cloudwatch-policy" {

  name = "AmazonEKSWorkerNodeCloudwatchPolicy"

  description = "Allows EKS worker nodes to send logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:PutRetentionPolicy",
          "logs:DescribeLogStreams"
        ]

        Resource = "*"
      }
    ]
  })
}


##############################################
# CloudWatch Policy Attachment
##############################################

resource "aws_iam_role_policy_attachment" "amazon-eks-worker-node-cloudwatch-policy-attachment" {

  role       = aws_iam_role.nodes.name
  policy_arn = aws_iam_policy.amazon-eks-worker-node-cloudwatch-policy.arn
}


##############################################
# EKS Worker Node Policy
##############################################

resource "aws_iam_role_policy_attachment" "amazon-eks-worker-node-policy" {

  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}


##############################################
# EKS CNI Policy
##############################################

resource "aws_iam_role_policy_attachment" "amazon-eks-cni-policy" {

  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


##############################################
# ECR Read Only Policy
##############################################

resource "aws_iam_role_policy_attachment" "amazon-ec2-container-registry-read-only" {

  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


##############################################
# Secrets Manager Policy
##############################################

resource "aws_iam_policy" "secrets_manager" {

  name        = "de-prod-secrets-manager-policy"
  description = "Allows EKS nodes to read secrets from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]

        Resource = "*"
      }
    ]
  })
}


##############################################
# Secrets Manager Policy Attachment
##############################################

resource "aws_iam_role_policy_attachment" "secrets-manager-policy-attachment" {

  role       = aws_iam_role.nodes.name
  policy_arn = aws_iam_policy.secrets_manager.arn
}


##############################################
# EKS Managed Node Group
##############################################

resource "aws_eks_node_group" "private-nodes" {

  cluster_name    = aws_eks_cluster.cluster.name
  version         = var.cluster_version
  node_group_name = "${var.cluster_name}-private-node-group"

  node_role_arn = aws_iam_role.nodes.arn

  subnet_ids = aws_subnet.private[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 10
  }

  remote_access {
    ec2_ssh_key = var.ec2_ssh_key

    source_security_group_ids = [
      aws_security_group.eks_sg.id
    ]
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.amazon-eks-worker-node-policy,
    aws_iam_role_policy_attachment.amazon-eks-cni-policy,
    aws_iam_role_policy_attachment.amazon-ec2-container-registry-read-only,
    aws_iam_role_policy_attachment.amazon-eks-worker-node-cloudwatch-policy-attachment,
    aws_iam_role_policy_attachment.secrets-manager-policy-attachment
  ]

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size
    ]
  }

  tags = {
    Name       = "${var.cluster_name}-private-node-group"
    cluster    = var.cluster_name
    created_by = "terraform"
  }
}


############################################################
# KARPENTER NODE IAM ROLE
#
# Used by EC2 instances launched by Karpenter.
############################################################

resource "aws_iam_role" "karpenter_node" {

  name = "${var.cluster_name}-karpenter-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name       = "${var.cluster_name}-karpenter-node-role"
    cluster    = var.cluster_name
    created_by = "terraform"
  }
}


############################################################
# Karpenter Node - EKS Worker Node Policy
############################################################

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {

  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"

  depends_on = [
    aws_iam_role.karpenter_node
  ]
}


############################################################
# Karpenter Node - EKS CNI Policy
############################################################

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {

  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"

  depends_on = [
    aws_iam_role.karpenter_node
  ]
}


############################################################
# Karpenter Node - ECR Read Only
############################################################

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {

  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"

  depends_on = [
    aws_iam_role.karpenter_node
  ]
}


############################################################
# Karpenter Node - SSM Managed Instance Core
############################################################

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {

  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

  depends_on = [
    aws_iam_role.karpenter_node
  ]
}


############################################################
# Karpenter Node - CloudWatch
############################################################

resource "aws_iam_role_policy_attachment" "karpenter_node_cloudwatch" {

  role       = aws_iam_role.karpenter_node.name
  policy_arn = aws_iam_policy.amazon-eks-worker-node-cloudwatch-policy.arn

  depends_on = [
    aws_iam_role.karpenter_node
  ]
}


############################################################
# Karpenter Node - Secrets Manager
############################################################

resource "aws_iam_role_policy_attachment" "karpenter_node_secrets_manager" {

  role       = aws_iam_role.karpenter_node.name
  policy_arn = aws_iam_policy.secrets_manager.arn

  depends_on = [
    aws_iam_role.karpenter_node
  ]
}


############################################################
# Karpenter EC2 Instance Profile
############################################################

resource "aws_iam_instance_profile" "karpenter_node" {

  name = "${var.cluster_name}-karpenter-node-instance-profile"

  role = aws_iam_role.karpenter_node.name

  tags = {
    Name       = "${var.cluster_name}-karpenter-node-instance-profile"
    cluster    = var.cluster_name
    created_by = "terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_node_worker,
    aws_iam_role_policy_attachment.karpenter_node_cni,
    aws_iam_role_policy_attachment.karpenter_node_ecr,
    aws_iam_role_policy_attachment.karpenter_node_ssm,
    aws_iam_role_policy_attachment.karpenter_node_cloudwatch,
    aws_iam_role_policy_attachment.karpenter_node_secrets_manager
  ]
}