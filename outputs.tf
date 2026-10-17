# ============================================================
# AWS Enterprise Landing Zone — Root Outputs
# ============================================================

output "organization_id" {
  description = "AWS Organisation ID."
  value       = module.organization.organization_id
}

output "organization_arn" {
  description = "AWS Organisation ARN."
  value       = module.organization.organization_arn
}

output "security_account_id" {
  description = "Account ID of the Security account."
  value       = module.accounts.security_account_id
}

output "logging_account_id" {
  description = "Account ID of the Logging account."
  value       = module.accounts.logging_account_id
}

output "shared_services_account_id" {
  description = "Account ID of the Shared Services account."
  value       = module.accounts.shared_services_account_id
}

output "development_account_id" {
  description = "Account ID of the Development account."
  value       = module.accounts.development_account_id
}

output "production_account_id" {
  description = "Account ID of the Production account."
  value       = module.accounts.production_account_id
}

output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket storing CloudTrail logs."
  value       = module.logging.cloudtrail_bucket_name
}

output "cloudtrail_trail_arn" {
  description = "ARN of the organisation CloudTrail trail."
  value       = module.cloudtrail.trail_arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID in the Security account."
  value       = module.guardduty.detector_id
}

output "kms_cloudtrail_key_arn" {
  description = "ARN of the KMS key encrypting CloudTrail logs."
  value       = module.kms.cloudtrail_key_arn
  sensitive   = true
}

output "monitoring_dashboard_name" {
  description = "Name of the CloudWatch dashboard."
  value       = module.monitoring.dashboard_name
}

# ------- Networking / Security Group / NAT Outputs ---------------

output "af_south_1" {
  description = "Primary Region Networking outputs for af-south-1."
  value = {
    region              = module.networking_af_south_1.region
    vpc_id              = module.networking_af_south_1.vpc_id
    vpc_cidr_block      = module.networking_af_south_1.vpc_cidr_block
    azs                 = module.networking_af_south_1.azs
    public_subnet_ids   = module.networking_af_south_1.public_subnet_ids
    private_subnet_ids  = module.networking_af_south_1.private_subnet_ids
    database_subnet_ids = module.networking_af_south_1.database_subnet_ids
    db_subnet_group     = module.networking_af_south_1.database_subnet_group_name
    nat_public_ips      = module.networking_af_south_1.nat_public_ips
  }
}

output "eu_west_1" {
  description = "DR Region Networking outputs for eu-west-1."
  value = {
    region              = module.networking_eu_west_1.region
    vpc_id              = module.networking_eu_west_1.vpc_id
    vpc_cidr_block      = module.networking_eu_west_1.vpc_cidr_block
    azs                 = module.networking_eu_west_1.azs
    public_subnet_ids   = module.networking_eu_west_1.public_subnet_ids
    private_subnet_ids  = module.networking_eu_west_1.private_subnet_ids
    database_subnet_ids = module.networking_eu_west_1.database_subnet_ids
    db_subnet_group     = module.networking_eu_west_1.database_subnet_group_name
    nat_public_ips      = module.networking_eu_west_1.nat_public_ips
  }
}

output "vpc_id" {
  description = "Primary VPC ID"
  value       = module.networking_af_south_1.vpc_id
}

output "vpc_cidr_block" {
  description = "Primary VPC CIDR"
  value       = module.networking_af_south_1.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Primary public subnet IDs"
  value       = module.networking_af_south_1.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Primary private subnet IDs"
  value       = module.networking_af_south_1.private_subnet_ids
}

output "database_subnet_ids" {
  description = "Primary database subnet IDs"
  value       = module.networking_af_south_1.database_subnet_ids
}

output "database_subnet_group_name" {
  description = "Primary database subnet group"
  value       = module.networking_af_south_1.database_subnet_group_name
}

output "default_security_group_id" {
  description = "Default security group ID for the primary VPC"
  value       = module.networking_af_south_1.default_security_group_id
}

output "nat_public_ips" {
  description = "NAT Gateway public IP addresses in the primary region"
  value       = module.networking_af_south_1.nat_public_ips
}

output "availability_zones" {
  description = "Availability Zones used in the primary region"
  value       = module.networking_af_south_1.azs
}
