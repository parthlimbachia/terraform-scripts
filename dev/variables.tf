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

variable "db_identifier" {
  type        = string
  description = "Database identifier"
}

variable "db_instance_class" {
  type        = string
  description = "Database instance"
}

variable "db_version" {
  type        = string
  description = "Database version"
}

variable "db_storage" {
  type        = number
  description = "Database storage size"
}

variable "db_username" {
  type        = string
  description = "Database username"
}

variable "db_password" {
  type        = string
  description = "Database password"
}
