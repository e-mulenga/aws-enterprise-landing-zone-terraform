# ============================================================
# AWS Enterprise Landing Zone — Root Variables
# ============================================================

# ---- Identity & Organisation --------------------------------
variable "organization_name" {
  type        = string
  description = "Short name for the AWS Organisation (used in resource naming)."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.organization_name))
    error_message = "organization_name must be 3-30 lowercase alphanumeric characters or hyphens."
  }
}

variable "aws_region" {
  type        = string
  description = "Primary AWS region for all resources."
  default     = "af-south-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment: dev | test | prod."

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "organization_id" {
  description = "AWS Organizations ID (o-xxxxxxxxxx), used in the bucket policy conditions."
  type        = string

  validation {
    condition     = can(regex("^o-[a-z0-9]{10,32}$", var.organization_id))
    error_message = "organization_id must look like o-xxxxxxxxxx."
  }
}

# ---- Governance & tagging -------------------------------------
variable "owner" {
  type        = string
  description = "Team or individual responsible for the workload."
}

variable "cost_center" {
  type        = string
  description = "Cost center code for billing allocation."
}

variable "required_tags" {
  type        = map(string)
  description = "Additional tags applied to every resource."
  default     = {}
}

# ---- Account Emails (used by account-vending module) --------
variable "security_account_email" {
  type        = string
  description = "Root email address for the Security AWS account."
}

variable "logging_account_email" {
  type        = string
  description = "Root email address for the Logging AWS account."
}

variable "shared_services_account_email" {
  type        = string
  description = "Root email address for the Shared Services AWS account."
}

variable "development_account_email" {
  type        = string
  description = "Root email address for the Development AWS account."
}

variable "production_account_email" {
  type        = string
  description = "Root email address for the Production AWS account."
}

# ---- Account IDs (populated after accounts are vended) ------

variable "create_member_accounts" {
  type        = bool
  description = "Create the Security / Shared Services / Development / Production accounts. Off for a single personal account."
  default     = true
}

variable "management_account_id" {
  type        = string
  description = "AWS Account ID of the management (root/payer) account."
  default     = ""
}

variable "security_account_id" {
  type        = string
  description = "AWS Account ID of the Security account."
  default     = ""
}

variable "logging_account_id" {
  type        = string
  description = "AWS Account ID of the Logging account."
  default     = ""
}

variable "shared_services_account_id" {
  type        = string
  description = "AWS Account ID of the Shared Services account."
  default     = ""
}

# ---- Governance services (all free, OFF until you need them) ----------
variable "enable_scp" {
  type        = bool
  description = "Attach the Service Control Policies. Free, but SCPs do not apply to the management account, so they only matter once member accounts exist."
  default     = false
}

variable "enable_identity_center" {
  type        = bool
  description = "Create IAM Identity Center groups and assignments (free). Needs member accounts."
  default     = false
}

variable "enable_ai_governance" {
  type        = bool
  description = "Deploy the AI governance foundation (Bedrock guardrails, invocation logging, and model access policies)."
  default     = false
}

variable "enable_bedrock_invocation_logging" {
  type        = bool
  description = "Enable Amazon Bedrock invocation logging to capture model input/output for audit and compliance purposes."
  default     = true
}

variable "ai_audit_retention_days" {
  type        = number
  description = "Number of days to retain AI/Bedrock audit logs in CloudWatch."
  default     = 30
}

variable "approved_model_arns" {
  type        = list(string)
  description = "Foundation model ARNs workloads may use. Narrow this to the exact models you approve."
  default = [
    "arn:aws:bedrock:*::foundation-model/anthropic.*",
    "arn:aws:bedrock:*::foundation-model/amazon.titan-*",
    "arn:aws:bedrock:*::foundation-model/amazon.nova-*",
  ]
}

# ---- Region Controls ----------------------------------------
variable "allowed_regions" {
  type        = list(string)
  description = "Approved AWS regions. SCPs will deny activity outside this list."
  default     = ["af-south-1", "eu-west-1", "us-east-1"]
}

# ---- IAM Identity Center ------------------------------------
variable "identity_center_admin_group" {
  type        = string
  description = "Name of the IAM Identity Center group for cloud administrators."
  default     = "CloudAdmins"
}

# ---- Security Services --------------------------------------

variable "config_enabled" {
  type        = bool
  description = "Enable AWS Config across all accounts."
  default     = true
}

# ---- CloudTrail / Logging / Storage / Monitoring ------------
variable "cloudtrail_bucket_name" {
  type        = string
  default     = ""
  description = "Name of the CloudTrail bucket to CREATE. Ignored if existing_buckets.cloudtrail is set."
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log group retention for CloudTrail."
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "existing_buckets" {
  description = "Buckets that are already deployed. Named buckets are looked up (read-only); null ones are created."
  type = object({
    cloudtrail  = optional(string)
    config      = optional(string)
    guardduty   = optional(string)
    access_logs = optional(string)
  })
  default = {}
}

variable "logging_region" {
  description = "AWS region containing the centralized logging buckets"
  type        = string
  default     = "us-east-1"
}

# ---- Encryption ---------------------------------------------

variable "key_rotation_enabled" {
  type        = bool
  description = "Automatic rotation for customer managed keys (ignored when using AWS managed keys)."
  default     = true
}

variable "use_aws_managed_keys" {
  type        = bool
  description = "true = AWS managed keys, no CMKs (dev, test). false = five shared customer managed keys (prod, about USD 5/month)."
  default     = true
}

variable "use_aws_managed_kms" {
  description = "Use AWS-managed encryption instead of customer-managed KMS keys"
  type        = bool
  default     = true
}

# ---- Storage ------------------------------------------------
variable "s3_versioning_enabled" {
  type        = bool
  description = "Enable S3 versioning on the centralised log archive bucket."
  default     = true
}

# ---- Backup -------------------------------------------------
variable "backup_retention_days" {
  type        = number
  description = "AWS Backup recovery-point retention period"
  default     = 120

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "backup_retention_days must be between 7 and 365."
  }
}

variable "enable_backup" {
  type        = bool
  description = "Create the backup vault, plan and tag-based selection. The skeleton is free; charges start when resources are tagged BackupEnabled=true."
  default     = false
}

variable "backup_daily_retention_days" {
  type    = number
  default = 7
}

variable "backup_weekly_retention_days" {
  type    = number
  default = 28
}

variable "backup_monthly_retention_days" {
  type    = number
  default = 0
}

variable "backup_cross_region_copy" {
  type        = bool
  description = "Copy backups from af-south-1 to eu-west-1. Adds storage and transfer cost."
  default     = false
}

variable "backup_enable_vault_lock" {
  type        = bool
  description = "Immutable compliance lock. Production only."
  default     = false
}

# ---- Budget Alerting ----------------------------------------

# ---- Networking ----------------------------------------

# One object per region. CIDRs MUST NOT overlap if you plan to peer the VPCs.
variable "af_south_1" {
  description = "Network settings for af-south-1 (Cape Town)."
  type = object({
    vpc_cidr         = string
    public_subnets   = list(string)
    private_subnets  = list(string)
    database_subnets = list(string)
  })
}

variable "eu_west_1" {
  description = "Network settings for eu-west-1 (Ireland)."
  type = object({
    vpc_cidr         = string
    public_subnets   = list(string)
    private_subnets  = list(string)
    database_subnets = list(string)
  })
}

# ---- Budget Alerting ----------------------------------------

variable "budget_alert_email" {
  type        = string
  description = "Email address that receives budget alert notifications."
  default     = ""
}

variable "monthly_budget_usd" {
  type        = number
  description = "Monthly AWS spend budget. Alerts at 80% forecast and 100% actual."
  default     = 10
}

variable "enable_monitoring" {
  type        = bool
  description = "Dashboard (first three are free), SNS topic and monthly budget (first two are free)."
  default     = true
}

variable "enable_security_alarms" {
  type        = bool
  description = "CIS-style CloudWatch alarms (about USD 0.10 each). Needs a CloudTrail log group."
  default     = false
}

# ---- DNS (existing Route 53 zone) ------------------------------------
variable "route53_domain_name" {
  type        = string
  description = "Existing public hosted zone, for example example.com. Empty = DNS foundation off."
  default     = ""
}

variable "create_acm_certificates" {
  type        = bool
  description = "Request free wildcard ACM certificates (regional + us-east-1) validated in the existing zone."
  default     = true
}

# ---- Platform: GitHub OIDC and ECR -------------------------------------
variable "github_oidc_mode" {
  type        = string
  description = "disabled | lookup (provider already exists) | create."
  default     = "disabled"

  validation {
    condition     = contains(["disabled", "lookup", "create"], var.github_oidc_mode)
    error_message = "github_oidc_mode must be disabled, lookup or create."
  }
}

variable "github_oidc_roles" {
  description = "Optional GitHub Actions roles, trusted only for the listed repo subjects."
  type = map(object({
    description          = optional(string, "GitHub Actions role")
    subjects             = list(string)
    policy_arns          = optional(list(string), [])
    max_session_duration = optional(number, 3600)
  }))
  default = {}
}

variable "enable_ecr" {
  type        = bool
  description = "Shared ECR repositories. Empty repositories are free; storage only is billed."
  default     = true
}

variable "ecr_keep_last_images" {
  type    = number
  default = 10
}
