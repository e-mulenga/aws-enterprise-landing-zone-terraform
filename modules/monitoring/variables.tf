variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 365
}

variable "monthly_budget_usd" {
  type    = number
  default = 500
}

variable "budget_alert_email" {
  type    = string
  default = ""
}

variable "aws_region" {
  type = string
}

variable "cloudtrail_log_group" {
  type        = string
  default     = ""
  description = "CloudTrail CloudWatch Logs group (created by the cloudtrail module or an existing one). Empty = no metric filters or alarms."
}

variable "enable_security_alarms" {
  type        = bool
  default     = false
  description = "Create CIS-style metric filters and alarms (about USD 0.10 per alarm per month). Needs cloudtrail_log_group."
}

variable "enable_findings_feed" {
  type        = bool
  default     = true
  description = "Route GuardDuty / Security Hub / Config events to a log group for the dashboard (free rules, minimal log cost)."
}

variable "findings_retention_days" {
  type    = number
  default = 14
}

variable "sns_kms_key_id" {
  type        = string
  default     = null
  description = "CMK for the alerts topic. Must trust cloudwatch.amazonaws.com and events.amazonaws.com. null = unencrypted."
}
