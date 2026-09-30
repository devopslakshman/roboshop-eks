##############################################
# VPC Variables
##############################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)

  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)

  default = [
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
    team                     = "Devops"
    cluster                  = "kubernetes"
    product                  = "Roboshop"
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
# Public Subnet
##############################################

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.cluster_name}-public-subnet"
    Tier                     = "public"
    environment              = var.environment
    "kubernetes.io/role/elb" = "1"
    "karpenter.sh/discovery" = var.cluster_name
  }
}

##############################################
# Private Subnets
##############################################

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name                              = "${var.cluster_name}-private-subnet-${count.index + 1}"
    Tier                              = "private"
    environment                       = var.environment
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.cluster_name
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
# Public Route Table Association
##############################################

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

##############################################
# Elastic IP for NAT Gateway
##############################################

resource "aws_eip" "nat" {
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

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = {
    Name        = "${var.cluster_name}-nat-gateway"
    environment = var.environment
    created_by  = "terraform"
  }
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
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.nat.id
}
