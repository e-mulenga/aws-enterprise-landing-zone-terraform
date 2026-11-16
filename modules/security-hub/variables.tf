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

variable "alert_severity_labels" {
  type        = list(string)
  default     = ["CRITICAL", "HIGH"]
  description = "Severity labels of NEW findings that are e-mailed. Add MEDIUM for Access Analyzer or Inspector noise you want to see."

  validation {
    condition     = alltrue([for s in var.alert_severity_labels : contains(["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFORMATIONAL"], s)])
    error_message = "alert_severity_labels may only contain CRITICAL, HIGH, MEDIUM, LOW and INFORMATIONAL."
  }
}

variable "enable_finding_aggregator" {
  type        = bool
  default     = false
  description = "Aggregate findings from aggregator_regions into this Region."
}

variable "aggregator_regions" {
  type        = list(string)
  default     = ["eu-west-1"]
  description = "Regions linked to the aggregator."
}
