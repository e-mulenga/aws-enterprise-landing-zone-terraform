output "region" {
  description = "Region this VPC was deployed to."
  value       = data.aws_region.current.name
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block."
  value       = module.vpc.vpc_cidr_block
}

output "azs" {
  description = "Availability Zones used."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "Database subnet IDs."
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "Database subnet group name."
  value       = module.vpc.database_subnet_group_name
}

output "nat_public_ips" {
  description = "NAT gateway Elastic IPs (useful for partner allow-lists)."
  value       = module.vpc.nat_public_ips
}

output "default_security_group_id" {
  description = "Default security group ID."
  value       = module.vpc.default_security_group_id
}

output "security_group_id" {
  description = "ID of the custom VPC security group"
  value       = aws_security_group.main.id
}
