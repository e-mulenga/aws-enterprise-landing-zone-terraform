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
  security_ou_id                = module.organization.security_ou_id
  workloads_dev_ou_id           = module.organization.workloads_dev_ou_id
  workloads_prod_ou_id          = module.organization.workloads_prod_ou_id
  infrastructure_ou_id          = module.organization.infrastructure_ou_id
  security_account_email        = var.security_account_email
  logging_account_email         = var.logging_account_email
  shared_services_account_email = var.shared_services_account_email
  development_account_email     = var.development_account_email
  production_account_email      = var.production_account_email
  environment                   = var.environment

  depends_on = [module.organization]
}

# ---- 3. KMS Customer-Managed Keys --------------------------
module "kms" {
  source = "./modules/kms"

  environment           = var.environment
  organization_name     = var.organization_name
  key_rotation_enabled  = var.kms_key_rotation_enabled
  security_account_id   = var.security_account_id
  logging_account_id    = var.logging_account_id
  management_account_id = data.aws_caller_identity.current.account_id
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
  source = "./modules/cloudtrail"

  environment           = var.environment
  organization_name     = var.organization_name
  s3_bucket_name        = module.logging.cloudtrail_bucket_name
  kms_key_arn           = module.kms.cloudtrail_key_arn
  log_retention_days    = var.log_retention_days
  is_organization_trail = true

  depends_on = [module.logging]
}

# ---- 6. AWS Config -----------------------------------------
module "config" {
  source = "./modules/config"

  environment       = var.environment
  organization_name = var.organization_name
  s3_bucket_name    = module.logging.config_bucket_name
  kms_key_arn       = module.kms.config_key_arn
  enabled           = var.config_enabled

  depends_on = [module.logging]
}

# ---- 7. GuardDuty ------------------------------------------
module "guardduty" {
  source = "./modules/guardduty"

  providers = { aws = aws.security }

  environment       = var.environment
  organization_name = var.organization_name
  enabled           = var.guardduty_enabled
  findings_bucket   = module.logging.guardduty_bucket_name
  kms_key_arn       = module.kms.guardduty_key_arn

  depends_on = [module.accounts, module.logging]
}

# ---- 8. Security Hub ----------------------------------------
module "security_hub" {
  source = "./modules/security-hub"

  providers = { aws = aws.security }

  environment       = var.environment
  organization_name = var.organization_name
  enabled           = var.securityhub_enabled

  depends_on = [module.guardduty]
}

# ---- 9. SCPs ------------------------------------------------
module "scp" {
  source = "./modules/scp"

  organization_id      = module.organization.organization_id
  organization_root_id = module.organization.root_id
  allowed_regions      = var.allowed_regions
  environment          = var.environment

  depends_on = [module.accounts]
}

# ---- 10. IAM Identity Center --------------------------------
module "iam_identity_center" {
  source = "./modules/iam-identity-center"

  environment       = var.environment
  organization_name = var.organization_name
  admin_group_name  = var.identity_center_admin_group
  accounts          = module.accounts.account_map

  depends_on = [module.accounts]
}

# ---- 11. Backup --------------------------------------------
module "backup" {
  source = "./modules/backup"

  environment       = var.environment
  organization_name = var.organization_name
  retention_days    = var.backup_retention_days
  kms_key_arn       = module.kms.backup_key_arn

  depends_on = [module.kms]
}

# ---- 12. Monitoring ----------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  environment          = var.environment
  organization_name    = var.organization_name
  log_retention_days   = var.log_retention_days
  monthly_budget_usd   = var.monthly_budget_usd
  budget_alert_email   = var.budget_alert_email
  cloudtrail_log_group = module.cloudtrail.log_group_name

  depends_on = [module.cloudtrail]
}

# ---- Data Sources ------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
