variable "organization_name" {
  description = "Organization name used as a resource name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for this region's VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to use. Must match the number of subnets per tier."
  type        = number
  default     = 2
}

variable "public_subnets" {
  description = "Public subnet CIDRs, one per AZ."
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs, one per AZ."
  type        = list(string)
}

variable "database_subnets" {
  description = "Database subnet CIDRs, one per AZ."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = one shared NAT (cheaper, single point of failure). false = one NAT per AZ."
  type        = bool
  default     = true
}

variable "allow_public_web_ingress" {
  description = "Allow 80/443 from 0.0.0.0/0 on the default security group. Prefer false and use ALB/app-specific SGs."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags applied to all resources."
  type        = map(string)
  default     = {}
}
