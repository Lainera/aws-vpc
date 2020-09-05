data "aws_availability_zones" "main" {
  state = "available"
}

locals {
  create_gateway = length(var.AMI_ID) == 0
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
  count = local.create_gateway ? 1 : 0
  depends_on    = [aws_internet_gateway.igw]
  SUBNET_ID = aws_subnet.public[0].id
  ROUTE_TABLE_ID = aws_route_table.private.id
}

// Instance
resource "aws_instance" "nat_instance" {
  count = local.create_gateway ? 0 : 1
  depends_on    = [aws_internet_gateway.igw]
  ami = var.AMI_ID
  instance_type = "t3.micro"
  vpc_security_group_ids = [ aws_security_group.nat_instance[0].id ]
  subnet_id = aws_subnet.public[0].id
  source_dest_check = false

  credit_specification {
    cpu_credits = "standard"
  }
}

resource "aws_route" "private_nat_instance_routing" {
  count = local.create_gateway ? 0 : 1
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  instance_id         = aws_instance.nat_instance[0].id
}

resource "aws_security_group" "nat_instance" {
  count = local.create_gateway ? 0 : 1
  name_prefix = "nat-instance-"
  description = "Security group for nat instance: allow local Ingress any Egress"
  
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "nat-instance-sg"
  }

  ingress {
    description = "HTTPS from within VPC"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    description = "HTTP from within VPC"
    from_port = 80
    to_port = 80 
    protocol = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
 
  egress {
    description = "Any egress"
    from_port = 0
    to_port = 0 
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } 
}
