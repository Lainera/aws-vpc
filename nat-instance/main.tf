variable "AMI_ID" {
  type        = string
  description = "NAT instance AMI-ID, if not passed creates NAT gateway instead."
}

variable "SUBNET_ID" {
  type        = string
  description = "Public subnet to spawn instance in"
}

variable "ROUTE_TABLE_ID" {
  type        = string
  description = "Route table to associate route with"
}

data "aws_route_table" "private" {
  route_table_id = var.ROUTE_TABLE_ID
}

data "aws_subnet" "public" {
  id = var.SUBNET_ID
}

data "aws_vpc" "main" {
  id = data.aws_subnet.public.vpc_id
}

resource "aws_instance" "nat_instance" {
  ami                    = var.AMI_ID
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.nat_instance.id]
  subnet_id              = data.aws_subnet.public.id
  source_dest_check      = false

  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name = "nat-instance"
  }
}

resource "aws_route" "private_nat_instance_routing" {
  route_table_id         = data.aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.nat_instance.id
}

resource "aws_security_group" "nat_instance" {
  name_prefix = "nat-instance-"
  description = "Security group for nat instance: allow local Ingress any Egress"

  vpc_id = data.aws_vpc.main.id
  tags = {
    Name = "nat-instance-sg"
  }

  ingress {
    description = "HTTPS from within VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  ingress {
    description = "HTTP from within VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    description = "Any egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

