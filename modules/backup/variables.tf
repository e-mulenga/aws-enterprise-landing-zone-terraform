variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "CMK for the primary vault (shared-backup-key). null = AWS managed key aws/backup."
}

variable "dr_kms_key_arn" {
  type        = string
  default     = null
  description = "CMK in the DR region for the DR vault. null = AWS managed key aws/backup in that region."
}

# ---- Retention -----------------------------------------------
variable "daily_retention_days" {
  type        = number
  default     = 7
  description = "Retention of daily recovery points."

  validation {
    condition     = var.daily_retention_days >= 1
    error_message = "daily_retention_days must be at least 1."
  }
}

variable "weekly_retention_days" {
  type        = number
  default     = 28
  description = "Retention of weekly recovery points."

  validation {
    condition     = var.weekly_retention_days >= 7
    error_message = "weekly_retention_days must be at least 7."
  }
}

variable "monthly_retention_days" {
  type        = number
  default     = 0
  description = "Retention of monthly recovery points. 0 = no monthly rule (dev)."

  validation {
    condition     = var.monthly_retention_days == 0 || var.monthly_retention_days >= 30
    error_message = "monthly_retention_days must be 0 (disabled) or at least 30."
  }
}

variable "enable_cold_storage" {
  type        = bool
  default     = false
  description = "Move recovery points to cold storage. Only supported for some resource types and needs 90+ extra days of retention."
}

variable "cold_storage_after_days" {
  type    = number
  default = 30
}

# ---- Cross-region (af-south-1 -> eu-west-1) -------------------
variable "cross_region_copy_enabled" {
  type        = bool
  default     = false
  description = "Copy recovery points to the DR vault in eu-west-1. Adds storage and inter-region transfer cost."
}

variable "dr_copy_retention_days" {
  type        = number
  default     = 7
  description = "Retention of the daily copies in the DR vault."
}

# ---- Vault lock ------------------------------------------------
variable "enable_vault_lock" {
  type        = bool
  default     = false
  description = "Immutable compliance lock on the primary vault. PRODUCTION ONLY: cannot be undone after the cooling-off period."
}

variable "vault_lock_min_retention_days" {
  type    = number
  default = 7
}

variable "vault_lock_changeable_for_days" {
  type        = number
  default     = 3
  description = "Cooling-off period (min 3). After this the lock is permanent."

  validation {
    condition     = var.vault_lock_changeable_for_days >= 3
    error_message = "AWS requires at least 3 days."
  }
}
