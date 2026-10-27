variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "enabled" {
  type    = bool
  default = true
}

variable "create_detector" {
  type        = bool
  default     = true
  description = "false = a detector already exists in this region; look it up instead of creating one."
}

variable "finding_publishing_frequency" {
  type        = string
  default     = "SIX_HOURS"
  description = "FIFTEEN_MINUTES, ONE_HOUR or SIX_HOURS."
}

variable "organization_aware" {
  type        = bool
  default     = false
  description = "Auto-enable GuardDuty for all member accounts (needs the management / delegated admin account)."
}

variable "s3_protection" {
  type    = bool
  default = false
}

variable "eks_protection" {
  type    = bool
  default = false
}

variable "malware_protection" {
  type    = bool
  default = false
}

variable "findings_bucket" {
  type        = string
  default     = ""
  description = "Bucket for exported findings. Needs a CMK, so it is ignored when kms_key_arn is null."
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "CMK for the findings export (shared-s3-key). null in dev."
}

variable "sns_kms_key_id" {
  type        = string
  default     = null
  description = "CMK for the alerts topic. Must allow events.amazonaws.com. null = unencrypted topic."
}

variable "alert_email" {
  type        = string
  default     = ""
  description = "Email subscribed to high-severity findings. Empty = no subscription."
}
