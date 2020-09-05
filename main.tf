data "aws_availability_zones" "main" {
  state = "available"
}

locals {
  use_managed_nat = length(var.AMI_ID) == 0
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
    Tier = "Private"
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
    Tier = "Public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Public subnets route table"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.PUBLIC_SUBNET_COUNT
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
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

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Private subnets route table"
  }
}

resource "aws_route_table_association" "private" {
  count          = var.PRIVATE_SUBNET_COUNT
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

// NGW
module "nat_gateway" {
  source = "./nat-gateway"
  count = local.use_managed_nat ? 1 : 0
  depends_on    = [aws_internet_gateway.igw]
  SUBNET_ID = aws_subnet.public[0].id
  ROUTE_TABLE_ID = aws_route_table.private.id
}

// Instance
module "nat_instance" {
  source = "./nat-instance"
  count = local.use_managed_nat ? 0 : 1
  depends_on    = [aws_internet_gateway.igw]
  
  AMI_ID = var.AMI_ID

  SUBNET_ID = aws_subnet.public[0].id
  ROUTE_TABLE_ID = aws_route_table.private.id
}
