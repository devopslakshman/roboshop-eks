
##############################################
# Variables
##############################################

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet in us-east-1a"
  type        = string
  default     = "10.0.0.0/24"
}

variable "public_subnet_b_cidr" {
  description = "Public subnet in us-east-1b"
  type        = string
  default     = "10.0.4.0/24"
}

variable "public_subnet_c_cidr" {
  description = "Public subnet in us-east-1c"
  type        = string
  default     = "10.0.5.0/24"
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default     = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c"
  ]
}

##############################################
# VPC
##############################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name                     = "${var.cluster_name}-vpc"
    environment              = var.environment
    created_by               = "terraform"
    "karpenter.sh/discovery" = var.cluster_name
  }
}

##############################################
# Internet Gateway
##############################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.cluster_name}-igw"
    environment = var.environment
    created_by  = "terraform"
  }
}

##############################################
# Public Subnet - us-east-1a
##############################################

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name                                   = "${var.cluster_name}-public-subnet-${var.azs[0]}"
    Tier                                   = "public"
    environment                            = var.environment
    created_by                             = "terraform"
    "kubernetes.io/role/elb"               = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "karpenter.sh/discovery"               = var.cluster_name
  }
}

##############################################
# Public Subnet - us-east-1b
##############################################

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = var.azs[1]
  map_public_ip_on_launch = true

  tags = {
    Name                                   = "${var.cluster_name}-public-subnet-${var.azs[1]}"
    Tier                                   = "public"
    environment                            = var.environment
    created_by                             = "terraform"
    "kubernetes.io/role/elb"               = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "karpenter.sh/discovery"               = var.cluster_name
  }
}

##############################################
# Public Subnet - us-east-1c
##############################################

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_c_cidr
  availability_zone       = var.azs[2]
  map_public_ip_on_launch = true

  tags = {
    Name                                   = "${var.cluster_name}-public-subnet-${var.azs[2]}"
    Tier                                   = "public"
    environment                            = var.environment
    created_by                             = "terraform"
    "kubernetes.io/role/elb"               = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "karpenter.sh/discovery"               = var.cluster_name
  }
}

##############################################
# Public Route Table
##############################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.cluster_name}-public-rt"
    environment = var.environment
    created_by  = "terraform"
  }
}

##############################################
# Public Route Table Associations
##############################################

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

##############################################
# Private Subnets
##############################################

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                                   = "${var.cluster_name}-private-subnet-${var.azs[count.index]}"
    Tier                                   = "private"
    environment                            = var.environment
    created_by                             = "terraform"
    "kubernetes.io/role/internal-elb"      = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "karpenter.sh/discovery"               = var.cluster_name
  }
}

##############################################
# NAT Elastic IP
##############################################

resource "aws_eip" "nat" {
  vpc = true

  tags = {
    Name        = "${var.cluster_name}-nat-eip"
    environment = var.environment
    created_by  = "terraform"
  }
}

##############################################
# NAT Gateway
##############################################

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name        = "${var.cluster_name}-nat"
    environment = var.environment
    created_by  = "terraform"
  }

  depends_on = [
    aws_internet_gateway.igw
  ]
}

##############################################
# Private Route Table
##############################################

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name        = "${var.cluster_name}-private-rt"
    environment = var.environment
    created_by  = "terraform"
  }
}

##############################################
# Private Route Table Associations
##############################################

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

##############################################
# Outputs
##############################################

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet in us-east-1a"
  value       = aws_subnet.public.id
}

output "public_subnet_b_id" {
  description = "Public subnet in us-east-1b"
  value       = aws_subnet.public_b.id
}

output "public_subnet_c_id" {
  description = "Public subnet in us-east-1c"
  value       = aws_subnet.public_c.id
}

output "public_subnet_ids" {
  description = "All public subnet IDs"
  value = [
    aws_subnet.public.id,
    aws_subnet.public_b.id,
    aws_subnet.public_c.id
  ]
}

output "private_subnet_ids" {
  description = "All private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.nat.id
}
