# ============================================================
# AWS Enterprise Landing Zone — Root Orchestration
# ============================================================
# Modules are composed here; environment-specific values are
# supplied via environments/<env>/terraform.tfvars.
# ============================================================

# ---- 1. AWS Organisation ------------------------------------
module "organization" {
  source            = "./modules/organization"
  organization_name = var.organization_name
}

# ---- 2. Account Vending ------------------------------------
module "accounts" {
  count  = var.create_member_accounts ? 1 : 0
  source = "./modules/account-vending"

  organization_id               = module.organization.organization_id
  security_account_email        = var.security_account_email
  logging_account_email         = var.logging_account_email
  shared_services_account_email = var.shared_services_account_email
  development_account_email     = var.development_account_email
  production_account_email      = var.production_account_email
  environment                   = var.environment

  depends_on = [module.organization]
}

# ---- 3. Encryption: AWS managed keys (dev/test) or 5 shared CMKs (prod) ----
module "kms" {
  source = "./modules/kms"

  providers = {
    aws    = aws
    aws.dr = aws.eu_west_1
  }

  environment           = var.environment
  organization_name     = var.organization_name
  use_aws_managed_keys  = var.use_aws_managed_keys
  key_rotation_enabled  = var.key_rotation_enabled
  management_account_id = var.management_account_id
  logging_account_id    = var.logging_account_id
}

# Guard rail: customer managed keys are expected outside dev, and AWS managed
# keys are expected in dev. Warns (does not block) on a mismatch.
check "key_strategy_matches_environment" {
  assert {
    condition     = var.environment == "dev" ? var.use_aws_managed_keys : !var.use_aws_managed_keys
    error_message = "Unexpected key strategy for ${var.environment}: dev should use AWS managed keys; staging/prod should use customer managed keys."
  }
}

# ---- 4. Centralised Logging --------------------------------
module "logging" {
  source = "./modules/logging"

  providers = { aws = aws.logging }

  environment            = var.environment
  organization_name      = var.organization_name
  cloudtrail_bucket      = var.cloudtrail_bucket_name
  s3_versioning_enabled  = var.s3_versioning_enabled
  kms_key_arn            = module.kms.cloudtrail_key_arn # null in dev/test => SSE-S3
  log_retention_days     = var.log_retention_days
  organization_id        = module.organization.organization_id
  management_account_id  = data.aws_caller_identity.current.account_id
  existing_buckets       = var.existing_buckets
  archive_expiry_days    = var.log_archive_expiry_days
  access_log_expiry_days = var.access_log_expiry_days

  depends_on = [module.accounts, module.kms]
}

# ---- 5. CloudTrail (Org-level trail) -----------------------
module "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  source = "./modules/cloudtrail"

  providers = {
    aws = aws.logging
  }

  environment           = var.environment
  organization_name     = var.organization_name
  s3_bucket_name        = module.logging.cloudtrail_bucket_name
  kms_key_arn           = module.kms.cloudtrail_key_arn # null in dev => SSE-S3
  log_retention_days    = var.log_retention_days
  is_organization_trail = var.is_organization_trail
  data_events_enabled   = var.cloudtrail_data_events_enabled
  insights_enabled      = var.cloudtrail_insights_enabled

  depends_on = [
    module.logging,
    module.kms
  ]
}

# ---- 6. AWS Config -----------------------------------------
module "config" {
  count  = var.enable_config ? 1 : 0
  source = "./modules/config"

  environment         = var.environment
  organization_name   = var.organization_name
  s3_bucket_name      = module.logging.config_bucket_name
  kms_key_arn         = module.kms.config_key_arn
  enabled             = var.enable_config
  recording_frequency = var.config_recording_frequency
  rule_set            = var.config_rule_set

  depends_on = [
    module.logging,
    module.kms,
    module.cloudtrail
  ]
}

# ---- 7. GuardDuty ------------------------------------------
module "guardduty" {
  count  = var.guardduty_enabled ? 1 : 0
  source = "./modules/guardduty"

  environment        = var.environment
  organization_name  = var.organization_name
  enabled            = var.guardduty_enabled
  create_detector    = var.create_guardduty_detector
  organization_aware = var.guardduty_organization_aware
  findings_bucket    = module.logging.guardduty_bucket_name
  kms_key_arn        = module.kms.guardduty_key_arn
  alert_email        = var.alert_email

  depends_on = [module.accounts, module.logging]
}

# ---- 8. Security Hub ----------------------------------------
module "security_hub" {
  count  = var.securityhub_enabled ? 1 : 0
  source = "./modules/security-hub"

  providers = {
    aws = aws
  }

  environment        = var.environment
  organization_name  = var.organization_name
  standards          = var.securityhub_standards
  organization_aware = var.securityhub_organization_aware

  depends_on = [module.guardduty]
}

# ---- 9. SCPs ------------------------------------------------
module "scp" {
  count  = var.enable_scp ? 1 : 0
  source = "./modules/scp"

  organization_id      = module.organization.organization_id
  organization_root_id = module.organization.root_id
  allowed_regions      = var.allowed_regions
  environment          = var.environment

  ou_policies = {
    for name, p in var.ou_scps : name => {
      description     = p.description
      target_ou_ids   = [for k in p.target_ous : module.organization.ou_ids[k]]
      statements_json = p.statements_json
    }
  }

  depends_on = [module.accounts]
}

# ---- 10. IAM Identity Center --------------------------------
module "iam_identity_center" {
  count  = var.enable_identity_center && var.create_member_accounts ? 1 : 0
  source = "./modules/iam-identity-center"

  providers = {
    aws = aws.us-east-1
  }

  environment            = var.environment
  organization_name      = var.organization_name
  admin_group_name       = var.identity_center_admin_group
  accounts               = module.accounts[0].account_map
  custom_permission_sets = var.identity_center_custom_permission_sets

  depends_on = [module.accounts]
}

# ---- 11. Backup --------------------------------------------
module "backup" {
  count  = var.enable_backup ? 1 : 0
  source = "./modules/backup"

  providers = {
    aws    = aws
    aws.dr = aws.eu_west_1
  }

  environment               = var.environment
  organization_name         = var.organization_name
  kms_key_arn               = module.kms.backup_key_arn
  daily_retention_days      = var.backup_daily_retention_days
  weekly_retention_days     = var.backup_weekly_retention_days
  monthly_retention_days    = var.backup_monthly_retention_days
  cross_region_copy_enabled = var.backup_cross_region_copy
  enable_vault_lock         = var.backup_enable_vault_lock

  depends_on = [module.kms]
}

# ---- 12. Monitoring ----------------------------------------
module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "./modules/monitoring"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  aws_region             = var.aws_region
  environment            = var.environment
  organization_name      = var.organization_name
  log_retention_days     = var.log_retention_days
  monthly_budget_usd     = var.monthly_budget_usd
  budget_alert_email     = var.budget_alert_email != "" ? var.budget_alert_email : var.alert_email
  cloudtrail_log_group   = try(module.cloudtrail[0].log_group_name, var.existing_cloudtrail_log_group)
  enable_security_alarms = var.enable_security_alarms

  enable_cost_anomaly_detection = var.enable_cost_anomaly_detection
  anomaly_threshold_usd         = var.cost_anomaly_threshold_usd

  depends_on = [module.cloudtrail]
}

# ---- 13. Networking ------------------------------------------
module "networking_af_south_1" {
  source = "./modules/networking"

  providers = {
    aws = aws.af_south_1
  }

  organization_name        = var.organization_name
  environment              = var.environment
  vpc_cidr                 = var.af_south_1.vpc_cidr
  public_subnets           = var.af_south_1.public_subnets
  private_subnets          = var.af_south_1.private_subnets
  database_subnets         = var.af_south_1.database_subnets
  enable_nat_gateway       = var.enable_nat_gateway_primary
  single_nat_gateway       = var.single_nat_gateway
  allow_public_web_ingress = var.allow_public_web_ingress
  gateway_endpoints        = var.gateway_endpoints
  interface_endpoints      = var.interface_endpoints
}

module "networking_eu_west_1" {
  source = "./modules/networking"

  providers = {
    aws = aws.eu_west_1
  }

  organization_name        = var.organization_name
  environment              = var.environment
  vpc_cidr                 = var.eu_west_1.vpc_cidr
  public_subnets           = var.eu_west_1.public_subnets
  private_subnets          = var.eu_west_1.private_subnets
  database_subnets         = var.eu_west_1.database_subnets
  enable_nat_gateway       = var.enable_nat_gateway_dr
  single_nat_gateway       = var.single_nat_gateway
  allow_public_web_ingress = var.allow_public_web_ingress
  gateway_endpoints        = var.gateway_endpoints
  interface_endpoints      = var.interface_endpoints
}

# Guard: overlapping CIDRs would block peering later.
check "regional_vpc_cidrs_are_different" {
  assert {
    condition     = var.af_south_1.vpc_cidr != var.eu_west_1.vpc_cidr
    error_message = "The af-south-1 and eu-west-1 VPC CIDRs must be different."
  }
}

# ---- VPC Flow Logs: owned here. Other repos consume the outputs below,  --
# ---- they never create a second flow log against these VPCs. -----------
module "vpc_flow_logs_af_south_1" {
  count  = var.enable_vpc_flow_logs_primary ? 1 : 0
  source = "./modules/vpc-flow-logs"

  providers = {
    aws = aws.af_south_1
  }

  organization_name       = var.organization_name
  environment             = var.environment
  region_name             = "af-south-1"
  vpc_id                  = module.networking_af_south_1.vpc_id
  destination             = var.vpc_flow_logs_destination
  traffic_type            = var.vpc_flow_logs_traffic_type
  log_retention_days      = var.vpc_flow_logs_retention_days
  access_logs_bucket_name = module.logging.access_logs_bucket_name
  access_logs_bucket_arn  = module.logging.access_logs_bucket_arn
  s3_key_prefix           = "vpc-flow-logs/af-south-1/"
  kms_key_arn             = try(module.kms.shared_kms_keys["s3"].arn, null)
}

module "vpc_flow_logs_eu_west_1" {
  count  = var.enable_vpc_flow_logs_dr ? 1 : 0
  source = "./modules/vpc-flow-logs"

  providers = {
    aws = aws.eu_west_1
  }

  organization_name       = var.organization_name
  environment             = var.environment
  region_name             = "eu-west-1"
  vpc_id                  = module.networking_eu_west_1.vpc_id
  destination             = var.vpc_flow_logs_destination
  traffic_type            = var.vpc_flow_logs_traffic_type
  log_retention_days      = var.vpc_flow_logs_retention_days
  access_logs_bucket_name = module.logging.access_logs_bucket_name
  access_logs_bucket_arn  = module.logging.access_logs_bucket_arn
  s3_key_prefix           = "vpc-flow-logs/eu-west-1/"
  kms_key_arn             = try(module.kms.shared_kms_keys["s3"].arn, null)
}

# ---- Interface VPC Endpoints (PrivateLink): owned here. Other repos ------
# ---- consume the outputs below and never create a second endpoint for ----
# ---- the same service in these VPCs (private DNS allows only one). -------
# Services this Region does not offer are listed from the API, not assumed.

module "vpc_endpoints_af_south_1" {
  count  = var.enable_interface_endpoints_primary ? 1 : 0
  source = "./modules/vpc-endpoints"

  providers = {
    aws = aws.af_south_1
  }

  organization_name               = var.organization_name
  environment                     = var.environment
  vpc_id                          = module.networking_af_south_1.vpc_id
  vpc_cidr                        = module.networking_af_south_1.vpc_cidr_block
  subnet_ids                      = module.networking_af_south_1.private_subnet_ids
  availability_zones              = module.networking_af_south_1.azs
  interface_endpoints             = var.interface_endpoints_fallback_to_dr ? local.interface_endpoints_in_primary : var.interface_endpoints
  endpoint_policy_organization_id = var.restrict_interface_endpoints_to_organization ? var.organization_id : null
}

# DR Region: full mirror when enable_interface_endpoints_dr = true, otherwise only
# the services af-south-1 could not provide.
module "vpc_endpoints_eu_west_1" {
  count  = local.deploy_vpc_endpoints_dr ? 1 : 0
  source = "./modules/vpc-endpoints"

  providers = {
    aws = aws.eu_west_1
  }

  organization_name               = var.organization_name
  environment                     = var.environment
  vpc_id                          = module.networking_eu_west_1.vpc_id
  vpc_cidr                        = module.networking_eu_west_1.vpc_cidr_block
  subnet_ids                      = module.networking_eu_west_1.private_subnet_ids
  availability_zones              = module.networking_eu_west_1.azs
  interface_endpoints             = var.enable_interface_endpoints_dr ? var.interface_endpoints : local.interface_endpoints_dr_fallback
  additional_ingress_cidr_blocks  = length(local.interface_endpoints_dr_fallback) > 0 ? [var.af_south_1.vpc_cidr] : []
  endpoint_policy_organization_id = var.restrict_interface_endpoints_to_organization ? var.organization_id : null
}

# ---- 14. Route 53 foundation (existing hosted zone) + ACM -----------------
module "dns" {
  source = "./modules/dns"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  environment                   = var.environment
  organization_name             = var.organization_name
  domain_name                   = var.route53_domain_name
  create_certificates           = var.create_acm_certificates
  create_cloudfront_certificate = true
}

# ---- 15. Shared ECR --------------------------------------------------
module "ecr" {
  count  = var.enable_ecr ? 1 : 0
  source = "./modules/ecr"

  providers = {
    aws = aws
  }

  environment       = var.environment
  organization_name = var.organization_name
  keep_last_images  = var.ecr_keep_last_images
  organization_id   = var.organization_id
}

# ---- 16. AI governance foundation--------------------------------------------------
module "ai_governance" {
  count  = var.enable_ai_governance ? 1 : 0
  source = "./modules/ai-governance"

  providers = {
    aws    = aws
    aws.ai = aws.eu_west_1
  }

  environment               = var.environment
  organization_name         = var.organization_name
  kms_key_arn               = module.kms.shared_ai_key_arn
  audit_retention_days      = var.ai_audit_retention_days
  enable_invocation_logging = var.enable_bedrock_invocation_logging
  approved_model_arns       = var.approved_model_arns
}

# ---- 17. GitHub OIDC (passwordless CI/CD) ---------------------------
module "github_oidc" {
  count  = var.github_oidc_mode == "disabled" ? 0 : 1
  source = "./modules/github-oidc"

  environment       = var.environment
  organization_name = var.organization_name
  create_provider   = var.github_oidc_mode == "create"
  roles             = var.github_oidc_roles
}

# ---- 18. IAM Access Analyzer (free) -----------------------------
module "access_analyzer" {
  count  = var.enable_access_analyzer ? 1 : 0
  source = "./modules/access-analyzer"

  environment       = var.environment
  organization_name = var.organization_name
  analyzer_type     = var.access_analyzer_type
}

# ---- 19. Amazon Inspector (billed per scan, off by default) -----
module "inspector" {
  count  = var.enable_inspector ? 1 : 0
  source = "./modules/inspector"

  environment        = var.environment
  organization_name  = var.organization_name
  resource_types     = var.inspector_resource_types
  organization_aware = var.securityhub_organization_aware
}

# ---- 20. Amazon Macie (billed per bucket and GB, off by default) ---
module "macie" {
  count  = var.enable_macie ? 1 : 0
  source = "./modules/macie"

  environment       = var.environment
  organization_name = var.organization_name
}

# ---- 21. Config conformance pack and aggregator ------------------
module "config_compliance" {
  count  = var.enable_config_conformance_pack || var.enable_config_aggregator ? 1 : 0
  source = "./modules/config-compliance"

  environment             = var.environment
  organization_name       = var.organization_name
  enable_conformance_pack = var.enable_config_conformance_pack
  enable_aggregator       = var.enable_config_aggregator
  aggregator_regions      = ["af-south-1", "eu-west-1"]

  depends_on = [module.config]
}

# ---- 22. Organisation tag policy (free) -------------------------
module "tag_policies" {
  count  = var.enable_tag_policy ? 1 : 0
  source = "./modules/tag-policies"

  environment          = var.environment
  organization_name    = var.organization_name
  organization_root_id = module.organization.root_id
  enforced_for         = var.tag_policy_enforced_for
}

check "tag_policy_type_is_enabled" {
  assert {
    condition     = !var.enable_tag_policy || contains(module.organization.enabled_policy_types, "TAG_POLICY")
    error_message = "enable_tag_policy needs the TAG_POLICY policy type enabled on the organisation root: aws organizations enable-policy-type --root-id <root> --policy-type TAG_POLICY."
  }
}

# ---- 23. Cost and Usage Report (us-east-1) -----------------------
module "cost_reporting" {
  count  = var.enable_cost_reporting ? 1 : 0
  source = "./modules/cost-reporting"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  environment       = var.environment
  organization_name = var.organization_name
}

# ---- 24. DNS query logging and firewall (af-south-1 VPC) ---------
module "dns_security_af_south_1" {
  count  = var.enable_dns_query_logging_primary || length(var.dns_blocked_domains) > 0 ? 1 : 0
  source = "./modules/dns-security"

  providers = {
    aws = aws.af_south_1
  }

  environment          = var.environment
  organization_name    = var.organization_name
  vpc_id               = module.networking_af_south_1.vpc_id
  vpc_name             = "primary"
  enable_query_logging = var.enable_dns_query_logging_primary
  log_retention_days   = var.log_retention_days
  blocked_domains      = var.dns_blocked_domains
}

# ---- 25. Central CloudWatch observability ------------------------
module "observability" {
  count  = var.enable_central_observability ? 1 : 0
  source = "./modules/observability"

  environment       = var.environment
  organization_name = var.organization_name
  organization_id   = module.organization.organization_id
}
