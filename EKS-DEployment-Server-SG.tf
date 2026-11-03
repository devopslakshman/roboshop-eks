
resource "aws_security_group" "allow_all" {
  name        = "eks-deployment-server-SG"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow all inbound traffic from all IPv4 CIDRs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic to all IPv4 CIDRs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "eks-deployment-server-SG"
    Project     = "ROboshop"
    Environment = "dev"
    CreatedBy   = "Terraform"
  }
}
