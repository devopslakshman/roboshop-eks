##############################################
# Terraform Configuration
##############################################

terraform {
  required_version = "~> 1.0"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }

    tls = {
      source = "hashicorp/tls"
    }
  }
}


##############################################
# AWS Provider
##############################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      team       = "Devops"
      cluster    = "Roboshop-eks"
      product    = "Roboshop"
      state      = Roboshop""
      created_by = "terraform"
    }
  }
}


##############################################
# Helm Provider
##############################################

provider "helm" {
  kubernetes {
    host = aws_eks_cluster.cluster.endpoint

    cluster_ca_certificate = base64decode(
      aws_eks_cluster.cluster.certificate_authority[0].data
    )

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"

      args = [
        "eks",
        "get-token",
        "--cluster-name",
        aws_eks_cluster.cluster.name,
        "--region",
        var.aws_region
      ]
    }
  }
}


##############################################
# Kubectl Provider
##############################################

provider "kubectl" {
  host = aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(
    aws_eks_cluster.cluster.certificate_authority[0].data
  )

  load_config_file = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"

    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.cluster.name,
      "--region",
      var.aws_region
    ]
  }
}