variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "standards" {
  type        = list(string)
  default     = ["fsbp"]
  description = "Standards to subscribe to: fsbp, cis, nist."

  validation {
    condition     = alltrue([for s in var.standards : contains(["fsbp", "cis", "nist"], s)])
    error_message = "standards may only contain fsbp, cis and nist."
  }
}

variable "organization_aware" {
  type        = bool
  default     = false
  description = "Central configuration for all member accounts (management / delegated admin only)."
}

variable "sns_kms_key_id" {
  type        = string
  default     = null
  description = "CMK for the alerts topic. Must allow events.amazonaws.com. null = unencrypted topic."
}

variable "alert_email" {
  type        = string
  description = "E-mail for critical/high Security Hub findings. Empty = no subscription."
  default     = ""
}
