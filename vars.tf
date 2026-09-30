##############################################
# AWS Region
##############################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

##############################################
# Environment
##############################################

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

##############################################
# EKS Cluster Name
##############################################

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "Roboshop-EKS"
}

##############################################
# Cluster Name in Camelcase
##############################################

variable "cluster_name_in_camelcase" {
  description = "Cluster name used for IAM policy naming"
  type        = string
  default     = "Roboshop-EKS"
}

##############################################
# Kubernetes Version
##############################################

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.34"
}

##############################################
# EC2 SSH Key
##############################################

variable "ec2_ssh_key" {
  description = "EC2 SSH key pair"
  type        = string
  default     = "de-prod-compute-kp"
}