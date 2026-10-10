##############################################
# EKS / Karpenter Security Group
##############################################

resource "aws_security_group" "eks_sg" {
  name        = "${var.cluster_name}-eks-sg"
  description = "Security group for EKS cluster and Karpenter nodes"
  vpc_id      = aws_vpc.main.id

  ############################################
  # Allow all traffic between EKS/Karpenter
  # resources using the same Security Group
  ############################################

  ingress {
    description = "Allow all traffic between EKS and Karpenter nodes"

    from_port = 0
    to_port   = 0
    protocol  = "-1"

    self = true
  }

  ############################################
  # SSH
  ############################################

  ingress {
    description = "Allow SSH from VPC"

    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/16"
    ]
  }

  ############################################
  # Kubernetes NodePort
  ############################################

  ingress {
    description = "Allow Kubernetes NodePort traffic"

    from_port = 30000
    to_port   = 32767
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/16"
    ]
  }

  ############################################
  # HTTPS
  ############################################

  ingress {
    description = "Allow HTTPS traffic"

    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ############################################
  # HTTP
  ############################################

  ingress {
    description = "Allow HTTP traffic"

    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ############################################
  # All outbound traffic
  ############################################

  egress {
    description = "Allow all outbound traffic"

    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]

    ipv6_cidr_blocks = [
      "::/0"
    ]
  }

  ############################################
  # Tags
  ############################################

  tags = {
    Name                     = "${var.cluster_name}-eks-sg"
    environment              = var.environment
    team                     = "Devops"
    cluster                  = "kubernetes"
    product                  = "Roboshop"
    created_by               = "terraform"
    "karpenter.sh/discovery" = var.cluster_name
  }
}
