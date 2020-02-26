variable "REGION" {
  type        = string
  description = "Valid AWS region"
}

variable "CIDR_BLOCK" {
  type        = string
  description = "VPC CIDR Block"

  validation {
    condition     = can(regex("\\d{1,3}.\\d{1,3}.\\d{1,3}.\\d{1,3}/\\d{1,2}", var.CIDR_BLOCK))
    error_message = "Pass valid IPV4 CIDR Block."
  }
}

variable "PRIVATE_SUBNET_COUNT" {
  type        = number
  description = "How many private subnets to create"

  validation {
    condition     = var.PRIVATE_SUBNET_COUNT > 0 
    error_message = "At least one private subnet is required."
  }
}

variable "PUBLIC_SUBNET_COUNT" {
  type        = number
  description = "How many public subnets to create"

  validation {
    condition     = var.PUBLIC_SUBNET_COUNT > 0 
    error_message = "At least one public subnet is required."
  }
}

