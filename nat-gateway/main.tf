variable "SUBNET_ID" {
  type        = string
  description = "Public subnet to host NAT gateway"
}

variable "ROUTE_TABLE_ID" {
  type        = string
  description = "Route table to add routes to"
}

data "aws_subnet" "public" {
  id = var.SUBNET_ID
}

data "aws_route_table" "private" {
  route_table_id = var.ROUTE_TABLE_ID
}

resource "aws_eip" "nat_public" {
  vpc = true
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat_public.id
  subnet_id     = data.aws_subnet.public.id
  tags = {
    Name        = "Nat gateway"
    description = "Nat gateway for private subnets"
  }
}

resource "aws_route" "private_ngw_routing" {
  route_table_id         = data.aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw.id
}
