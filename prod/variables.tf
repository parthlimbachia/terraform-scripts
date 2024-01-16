variable "environment" {
  type        = string
  description = "Environment"
}

variable "cidr_range" {
  type        = string
  description = "CIDR range for the VPC"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private Subnet CIDR values"
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
}
