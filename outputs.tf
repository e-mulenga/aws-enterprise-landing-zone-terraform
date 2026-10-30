# ============================================================
# AWS Enterprise Landing Zone - Root Outputs (the consumer contract)
# ============================================================
# Other repositories consume these through terraform_remote_state
# (see docs/consumption-guide.md). Keep names stable; bump
# contract_schema_version in locals.tf for any breaking change.
#
# A value is null when its service is not deployed in this environment.
# ============================================================

output "organization_id" {
  description = "AWS Organisation ID."
  value       = module.organization.organization_id
}

output "organization_arn" {
  description = "AWS Organisation ARN."
  value       = module.organization.organization_arn
}

output "ou_ids" {
  description = "Organisational Unit IDs by name."
  value       = module.organization.ou_ids
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

# ---------- Route 53 / certificates --------------------------
output "route53_zone_id" {
  description = "Existing hosted zone ID. null if route53_domain_name is not set."
  value       = module.dns.route53_zone_id
}

output "route53_domain_name" {
  description = "Existing domain name."
  value       = module.dns.route53_domain_name
}

output "acm_certificate_arn" {
  description = "Wildcard certificate in the primary Region."
  value       = module.dns.certificate_arn
}

output "acm_cloudfront_certificate_arn" {
  description = "Wildcard certificate in us-east-1 for CloudFront."
  value       = module.dns.cloudfront_certificate_arn
}

# ---------- Platform -----------------------------------------
output "github_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN. null when github_oidc_mode = disabled."
  value       = try(module.github_oidc[0].github_oidc_provider_arn, null)
}

output "github_oidc_role_arns" {
  description = "Optional GitHub Actions role ARNs."
  value       = try(module.github_oidc[0].role_arns, {})
}

output "ecr_repository_urls" {
  description = "Shared ECR repository URLs by short name."
  value       = try(module.ecr[0].ecr_repository_urls, {})
}

# ---------- Backup -------------------------------------------
output "backup_vault_name" {
  description = "Primary backup vault. null when enable_backup = false."
  value       = try(module.backup[0].vault_name, null)
}

output "backup_vault_arn" {
  value = try(module.backup[0].vault_arn, null)
}

output "backup_dr_vault_arn" {
  description = "DR vault in eu-west-1. null unless cross-region copy is on."
  value       = try(module.backup[0].dr_vault_arn, null)
}

# ------- Networking / Security Group / NAT / VPC Flow Logs Outputs ---------------
output "af_south_1" {
  description = "Primary Region (af-south-1) networking."
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
  description = "Disaster recovery Region (eu-west-1) networking."
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

# output "vpc_flow_logs" {
#   description = "VPC Flow Logs owned by this Landing Zone, by Region. Consumers read log_group_name/arn or s3_bucket_name/s3_key_prefix here and must never create a second flow log against these VPCs — the EC2 API also rejects a duplicate outright."
#   value       = module.vpc_flow_logs_outputs
# }

output "flow_log_group_names" {
  value = {
    af_south_1 = try(module.vpc_flow_logs_af_south_1[0].log_group_name, null)
    eu_west_1  = try(module.vpc_flow_logs_eu_west_1[0].log_group_name, null)
  }
}

output "vpc_flow_logs" {
  description = "Landing Zone VPC Flow Log configuration"

  value = {
    af_south_1 = {
      flow_log_ids  = try(module.vpc_flow_logs_af_south_1[0].flow_log_ids, [])
      log_group     = try(module.vpc_flow_logs_af_south_1[0].log_group_name, null)
      destination   = try(module.vpc_flow_logs_af_south_1[0].destination, null)
      bucket_prefix = try(module.vpc_flow_logs_af_south_1[0].s3_key_prefix, null)
    }

    eu_west_1 = {
      flow_log_ids  = try(module.vpc_flow_logs_eu_west_1[0].flow_log_ids, [])
      log_group     = try(module.vpc_flow_logs_eu_west_1[0].log_group_name, null)
      destination   = try(module.vpc_flow_logs_eu_west_1[0].destination, null)
      bucket_prefix = try(module.vpc_flow_logs_eu_west_1[0].s3_key_prefix, null)
    }
  }
}

# ---------- KMS / Encryption -----------

# Customer managed key ARNs; null in dev.
output "kms_key_arns" {
  value = {
    cloudtrail = module.kms.cloudtrail_key_arn
    config     = module.kms.config_key_arn
    guardduty  = module.kms.guardduty_key_arn
    backup     = module.kms.backup_key_arn
  }
  sensitive = true
}

output "kms_cloudtrail_key_arn" {
  description = "ARN of the KMS key encrypting CloudTrail logs."
  value       = module.kms.cloudtrail_key_arn
  sensitive   = true
}

output "key_strategy" {
  description = "aws-managed (dev/test) or customer-managed (prod)."
  value       = module.kms.key_strategy
}

output "shared_kms_keys" {
  description = "Catalogue of shared-rds, shared-s3, shared-backup, shared-analytics and shared-ai keys (alias_name works in both strategies)."
  value       = module.kms.shared_kms_keys
}

output "shared_ai_key_arn" {
  description = "shared-ai-key ARN. null with AWS managed keys."
  value       = module.kms.shared_ai_key_arn
}

output "cloudtrail_key_arn" {
  description = "null when using AWS managed keys."
  value       = module.kms.cloudtrail_key_arn
  sensitive   = true
}

output "cloudtrail_key_id" {
  description = "null when using AWS managed keys."
  value       = module.kms.cloudtrail_key_id
}

output "config_key_arn" {
  description = "null when using AWS managed keys."
  value       = module.kms.config_key_arn
  sensitive   = true
}

output "guardduty_key_arn" {
  description = "null when using AWS managed keys."
  value       = module.kms.guardduty_key_arn
  sensitive   = true
}

output "backup_key_arn" {
  description = "null when using AWS managed keys."
  value       = module.kms.backup_key_arn
  sensitive   = true
}

# ----------Security / Logging / Buckets -------------

output "log_buckets" {
  description = "Name, ARN, region and source (created/existing) of every log bucket."
  value       = module.logging.buckets
}

output "cloudtrail_bucket_name" {
  value = module.logging.cloudtrail_bucket_name
}

output "cloudtrail_bucket_arn" {
  value = module.logging.cloudtrail_bucket_arn
}

output "config_bucket_name" {
  value = module.logging.config_bucket_name
}

output "config_bucket_arn" {
  value = module.logging.config_bucket_arn
}

output "guardduty_bucket_name" {
  value = module.logging.guardduty_bucket_name
}

output "guardduty_bucket_arn" {
  value = module.logging.guardduty_bucket_arn
}

output "access_logs_bucket_name" {
  value = module.logging.access_logs_bucket_name
}

output "access_logs_bucket_arn" {
  value = module.logging.access_logs_bucket_arn
}

output "cloudtrail_trail_arn" {
  value = try(module.cloudtrail[0].trail_arn, null)
}

output "cloudtrail_log_group_name" {
  value = try(module.cloudtrail[0].log_group_name, var.existing_cloudtrail_log_group == "" ? null : var.existing_cloudtrail_log_group)
}

# ---- Audit & detection services (cost money, OFF by default) -----------
variable "enable_cloudtrail" {
  type        = bool
  description = "Create the trail with Terraform. false when a trail already exists (console / other stack)."
  default     = false
}

variable "is_organization_trail" {
  type        = bool
  description = "Organization trail. Needs the management or a delegated admin account."
  default     = false
}

variable "cloudtrail_data_events_enabled" {
  type        = bool
  description = "S3 and Lambda data events (billed per event)."
  default     = false
}

variable "cloudtrail_insights_enabled" {
  type        = bool
  description = "CloudTrail Insights (billed per event analysed)."
  default     = false
}

variable "existing_cloudtrail_log_group" {
  type        = string
  description = "CloudWatch Logs group of an existing trail, used by the dashboard and alarms when this stack does not create the trail."
  default     = ""
}

variable "enable_config" {
  type        = bool
  description = "Create the AWS Config recorder, delivery channel and rules (billed per item and per evaluation). AWS allows one recorder per Region."
  default     = false
}

variable "existing_config_recorder_name" {
  type        = string
  description = "Name of an existing Config recorder, re-exported as config_recorder_name when enable_config = false."
  default     = ""
}

variable "config_recording_frequency" {
  type    = string
  default = "CONTINUOUS"
}

variable "config_rule_set" {
  type        = string
  description = "core = 9 rules, full = 20 rules."
  default     = "core"
}

variable "guardduty_enabled" {
  type        = bool
  description = "Create / manage GuardDuty. 30-day free trial, then usage-based."
  default     = false
}

variable "create_guardduty_detector" {
  type        = bool
  description = "false = a detector already exists in the Region; look it up instead."
  default     = true
}

variable "existing_guardduty_detector_id" {
  type        = string
  description = "Detector ID re-exported as guardduty_detector_id when guardduty_enabled = false."
  default     = ""
}

variable "guardduty_organization_aware" {
  type    = bool
  default = false
}

variable "securityhub_enabled" {
  type        = bool
  description = "Enable Security Hub. 30-day free trial, then billed per protected resource."
  default     = false
}

variable "securityhub_standards" {
  type        = list(string)
  description = "Standards to subscribe to: fsbp, cis, nist."
  default     = ["fsbp"]
}

variable "securityhub_organization_aware" {
  type    = bool
  default = false
}

variable "alert_email" {
  type        = string
  description = "Email for security alerts and budget notifications."
  default     = ""
}

# ---------- Monitoring --------------
output "landing_zone_dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = try(module.monitoring[0].dashboard_name, null)
}

output "monitoring_dashboard_name" {
  description = "Legacy name for landing_zone_dashboard_name."
  value       = try(module.monitoring[0].dashboard_name, null)
}

output "monitoring_alarm_names" {
  description = "Names of CloudWatch monitoring alarms"
  value       = try(one(module.monitoring[*].alarm_names), [])
}

output "monitoring_topic_arn" {
  description = "SNS topic used by monitoring alarms."
  value       = try(module.monitoring[0].alerts_topic_arn, null)
}

# ---------- Detection ----------------------------------------
output "guardduty_detector_id" {
  description = "GuardDuty detector ID (managed or existing). null if none."
  value       = local.guardduty_detector_id
}

output "config_recorder_name" {
  description = "AWS Config recorder name (managed or existing). null if none."
  value       = local.config_recorder_name
}

output "security_hub_enabled" {
  description = "true when this stack enables Security Hub."
  value       = var.securityhub_enabled
}

output "security_hub_account_id" {
  description = "Account that runs Security Hub. null when disabled."
  value       = var.securityhub_enabled ? data.aws_caller_identity.current.account_id : null
}

# ---------- AI governance ------------------------------------
output "bedrock_guardrails_enabled" {
  value = try(module.ai_governance[0].bedrock_guardrails_enabled, false)
}

output "bedrock_guardrail_id" {
  value = try(module.ai_governance[0].guardrail_id, null)
}

output "bedrock_guardrail_version" {
  value = try(module.ai_governance[0].guardrail_version, null)
}

output "bedrock_approved_models_policy_arn" {
  value = try(module.ai_governance[0].approved_models_policy_arn, null)
}

output "ai_audit_bucket_name" {
  value = try(module.ai_governance[0].ai_audit_bucket_name, null)
}

output "contract_schema_version" {
  description = "Version of the output contract. Changes only on breaking renames."
  value       = local.contract_schema_version
}


