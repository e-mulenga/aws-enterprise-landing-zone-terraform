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

  environment           = var.environment
  organization_name     = var.organization_name
  cloudtrail_bucket     = var.cloudtrail_bucket_name
  s3_versioning_enabled = var.s3_versioning_enabled
  kms_key_arn           = module.kms.cloudtrail_key_arn
  log_retention_days    = var.log_retention_days
  organization_id       = module.organization.organization_id
  management_account_id = data.aws_caller_identity.current.account_id

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
  enabled            = var.securityhub_enabled
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

  depends_on = [module.accounts]
}

# ---- 10. IAM Identity Center --------------------------------
module "iam_identity_center" {
  count  = var.enable_identity_center && var.create_member_accounts ? 1 : 0
  source = "./modules/iam-identity-center"

  environment       = var.environment
  organization_name = var.organization_name
  admin_group_name  = var.identity_center_admin_group
  accounts          = module.accounts[0].account_map

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

  aws_region             = var.aws_region
  environment            = var.environment
  organization_name      = var.organization_name
  log_retention_days     = var.log_retention_days
  monthly_budget_usd     = var.monthly_budget_usd
  budget_alert_email     = var.budget_alert_email != "" ? var.budget_alert_email : var.alert_email
  cloudtrail_log_group   = try(module.cloudtrail[0].log_group_name, var.existing_cloudtrail_log_group)
  enable_security_alarms = var.enable_security_alarms

  depends_on = [module.cloudtrail]
}

# ---- 13. Networking ------------------------------------------

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


