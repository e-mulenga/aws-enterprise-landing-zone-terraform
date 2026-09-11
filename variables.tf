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

# ---- Governance & Tagging -----------------------------------
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
  description = "Additional mandatory tags applied to all resources."
  default     = {}
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
variable "guardduty_enabled" {
  type        = bool
  description = "Enable Amazon GuardDuty across all member accounts."
  default     = true
}

variable "securityhub_enabled" {
  type        = bool
  description = "Enable AWS Security Hub in the Security account."
  default     = true
}

variable "config_enabled" {
  type        = bool
  description = "Enable AWS Config across all accounts."
  default     = true
}

# ---- CloudTrail / Logging -----------------------------------
variable "cloudtrail_bucket_name" {
  type        = string
  description = "Name of the S3 bucket that receives organisation CloudTrail logs."
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch Logs retention period in days."
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

# ---- Encryption ---------------------------------------------
variable "kms_key_rotation_enabled" {
  type        = bool
  description = "Enable automatic annual rotation for KMS customer-managed keys."
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
  description = "Number of days to retain AWS Backup recovery points."
  default     = 35

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "backup_retention_days must be between 7 and 365."
  }
}

# ---- Budget Alerting ----------------------------------------
variable "monthly_budget_usd" {
  type        = number
  description = "Monthly AWS spend budget threshold in USD. Alerts trigger at 80% and 100%."
  default     = 500
}

variable "budget_alert_email" {
  type        = string
  description = "Email address that receives budget alert notifications."
  default     = ""
}
