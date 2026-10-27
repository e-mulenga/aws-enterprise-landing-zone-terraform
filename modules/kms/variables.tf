variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "use_aws_managed_keys" {
  type        = bool
  default     = true
  description = "true = AWS managed keys for all services (dev/test, no CMKs created). false = five shared customer managed keys (prod)."
}

variable "key_rotation_enabled" {
  type        = bool
  default     = true
  description = "Automatic rotation for CMKs. Ignored when use_aws_managed_keys = true."
}

variable "deletion_window_in_days" {
  type        = number
  default     = 30
  description = "Waiting period before a deleted CMK is removed (7-30)."

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "management_account_id" {
  type        = string
  default     = ""
  description = "Management account ID used in the CloudTrail key condition. Empty = the current account."

  validation {
    condition     = var.management_account_id == "" || can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "management_account_id must be empty or a 12-digit account ID."
  }
}

variable "logging_account_id" {
  type        = string
  default     = ""
  description = "Log archive account ID allowed to decrypt logs. Empty = no cross-account decrypt statement."

  validation {
    condition     = var.logging_account_id == "" || can(regex("^[0-9]{12}$", var.logging_account_id))
    error_message = "logging_account_id must be empty or a 12-digit account ID."
  }
}
