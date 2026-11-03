resource "aws_spot_instance_request" "spot_ec2" {
  ami           = "ami-0d593373e950b7425"
  instance_type = "t3.micro"

  spot_type            = "one-time"
  wait_for_fulfillment = true

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.allow_all.id]

  associate_public_ip_address = true

  tags = {
    Name        = "EKS-Deployment-server"
    Environment = "dev"
    CreatedBy   = "Terraform"
  }
}

resource "aws_ec2_tag" "spot_instance_name" {
  resource_id = aws_spot_instance_request.spot_ec2.spot_instance_id
  key         = "Name"
  value       = "EKS-Deployment-server"
}