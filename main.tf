provider "aws" {
  region = var.REGION
}

terraform {
  experiments = [
    variable_validation
  ]
}

data "aws_availability_zones" "main" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.CIDR_BLOCK
  enable_dns_hostnames = true
}

resource "aws_subnet" "private" {
  count             = var.PRIVATE_SUBNET_COUNT
  vpc_id            = aws_vpc.main.id
  availability_zone = data.aws_availability_zones.main.names[count.index]
  cidr_block        = cidrsubnet(var.CIDR_BLOCK, 4, count.index)
  tags = {
    Name = "Private subnet ${count.index}"
  }
}

resource "aws_subnet" "public" {
  count                   = var.PUBLIC_SUBNET_COUNT
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.main.names[count.index]
  cidr_block              = cidrsubnet(var.CIDR_BLOCK, 4, count.index + var.PRIVATE_SUBNET_COUNT)
  map_public_ip_on_launch = true

  tags = {
    Name = "Public subnet ${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Public subnets route table"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Public subnet internet gateway"
  }
}

resource "aws_route" "public_igw_routing" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count          = var.PUBLIC_SUBNET_COUNT
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_nat_gateway" "ngw" {
  depends_on    = [aws_internet_gateway.igw, aws_eip.nat_public]
  allocation_id = aws_eip.nat_public.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name        = "Nat gateway"
    description = "Nat gateway for private subnets"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Private subnets route table"
  }
}

resource "aws_route" "private_nat_routing" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw.id
}

resource "aws_route_table_association" "private" {
  count          = var.PRIVATE_SUBNET_COUNT
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_eip" "nat_public" {
  vpc = true
}
