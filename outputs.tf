# ============================================================
# AWS Enterprise Landing Zone - Root Outputs (the consumer contract)
# ============================================================
# Other repositories consume these through terraform_remote_state
# (see docs/consumption-guide.md). Keep names stable; bump
# contract_schema_version in locals.tf for any breaking change.
#
# A value is null when its service is not deployed in this environment.
# ============================================================

# ---------- Accounts / Organizational Units / Organizational ID -------------
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

# ---------- Interface VPC Endpoints (PrivateLink) --------------
# Primary Region (af-south-1). Null / empty when
# enable_interface_endpoints_primary = false. Downstream repositories reference
# the security group in their egress rules instead of 0.0.0.0/0, and never
# create a second endpoint for the same service in this VPC.
output "interface_endpoint_security_group_id" {
  description = "Shared security group attached to every Interface endpoint in the primary VPC (af-south-1). null when interface endpoints are not deployed."
  value       = try(module.vpc_endpoints_af_south_1[0].security_group_id, null)
}

output "interface_endpoints" {
  description = "Interface endpoint IDs in the primary VPC (af-south-1), keyed sqs, sns, secretsmanager, logs, eventbridge, kms, monitoring, xray, ecr_api, ecr_dkr, sts. Only deployed services appear; {} when not deployed."
  value       = try(module.vpc_endpoints_af_south_1[0].endpoint_ids, {})
}

output "interface_endpoints_dr_fallback_services" {
  description = "Services that af-south-1 does not offer as Interface endpoints and that are served from the eu-west-1 DR VPC instead (see interface_endpoints_fallback_to_dr). Their IDs are under vpc_interface_endpoints.eu_west_1. [] when none."
  value       = local.interface_endpoints_dr_fallback
}

output "vpc_interface_endpoints" {
  description = "Landing Zone Interface VPC Endpoint (PrivateLink) configuration by Region."

  value = {
    af_south_1 = {
      enabled             = length(module.vpc_endpoints_af_south_1) > 0
      security_group_id   = try(module.vpc_endpoints_af_south_1[0].security_group_id, null)
      endpoint_ids        = try(module.vpc_endpoints_af_south_1[0].endpoint_ids, {})
      endpoint_dns_names  = try(module.vpc_endpoints_af_south_1[0].endpoint_dns_names, {})
      service_names       = try(module.vpc_endpoints_af_south_1[0].service_names, [])
      private_dns_enabled = try(module.vpc_endpoints_af_south_1[0].private_dns_enabled, null)
    }

    eu_west_1 = {
      enabled             = var.enable_interface_endpoints_dr
      deployed            = local.deploy_vpc_endpoints_dr
      security_group_id   = try(module.vpc_endpoints_eu_west_1[0].security_group_id, null)
      endpoint_ids        = try(module.vpc_endpoints_eu_west_1[0].endpoint_ids, {})
      endpoint_dns_names  = try(module.vpc_endpoints_eu_west_1[0].endpoint_dns_names, {})
      service_names       = try(module.vpc_endpoints_eu_west_1[0].service_names, [])
      private_dns_enabled = try(module.vpc_endpoints_eu_west_1[0].private_dns_enabled, null)
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

output "config_recorder_name" {
  description = "AWS Config recorder name (managed or existing). null if none."
  value       = one(module.config[*].recorder_name)
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

output "access_analyzer_arn" {
  description = "ARN of the IAM Access Analyzer, or null when it is off."
  value       = try(module.access_analyzer[0].analyzer_arn, null)
}

output "inspector_enabled_resource_types" {
  description = "Resource types Amazon Inspector scans, or an empty list when it is off."
  value       = try(module.inspector[0].enabled_resource_types, [])
}

output "macie_enabled" {
  description = "true when Amazon Macie is enabled in this account."
  value       = length(module.macie) > 0
}

output "config_conformance_pack_name" {
  description = "Name of the baseline Config conformance pack, or null when it is off."
  value       = try(module.config_compliance[0].conformance_pack_name, null)
}

output "config_aggregator_name" {
  description = "Name of the organisation Config aggregator, or null when it is off."
  value       = try(module.config_compliance[0].aggregator_name, null)
}

output "tag_policy_id" {
  description = "ID of the organisation tag policy, or null when it is off."
  value       = try(module.tag_policies[0].tag_policy_id, null)
}

output "ou_scp_policy_ids" {
  description = "IDs of the per-OU service control policies, by policy name."
  value       = try(module.scp[0].ou_policy_ids, {})
}

output "identity_center_permission_set_arns" {
  description = "IAM Identity Center permission set ARNs by name, or an empty map when Identity Center is off."
  value       = try(module.iam_identity_center[0].permission_set_arns, {})
}

output "additional_account_ids" {
  description = "IDs of the accounts vended through additional_accounts, by name."
  value       = module.accounts.additional_account_ids
}

output "cost_report_bucket_name" {
  description = "Bucket (us-east-1) holding the Cost and Usage Report, or null when it is off."
  value       = try(module.cost_reporting[0].cur_bucket_name, null)
}

output "dns_query_log_group_name" {
  description = "Log group with Route 53 Resolver query logs for the af-south-1 VPC, or null when off."
  value       = try(module.dns_security_af_south_1[0].query_log_group_name, null)
}

output "dns_firewall_rule_group_id" {
  description = "Route 53 DNS Firewall rule group for the af-south-1 VPC, or null when no domains are blocked."
  value       = try(module.dns_security_af_south_1[0].firewall_rule_group_id, null)
}

output "observability_sink_arn" {
  description = "CloudWatch cross-account observability sink. Member accounts link to it with aws_oam_link. null when off."
  value       = try(module.observability[0].sink_arn, null)
}

output "kms_dr_replica_key_arns" {
  description = "eu-west-1 replicas of the shared keys by purpose. Empty unless dr_kms_replicas_enabled = true with customer managed keys."
  value       = module.kms.dr_replica_key_arns
}

output "backup_dr_key_arn" {
  description = "eu-west-1 replica of shared-backup-key, or null."
  value       = module.kms.backup_dr_key_arn
}

output "contract_schema_version" {
  description = "Version of the output contract. Changes only on breaking renames."
  value       = local.contract_schema_version
}

output "terraform_state" {
  description = "Where this stack's state lives, so downstream repositories can configure terraform_remote_state without asking. Not secret."
  value = {
    bucket = var.state_bucket_name
    key    = var.state_key
    region = var.state_region
  }
}
