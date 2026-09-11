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

variable "cloudtrail_log_group" {
  type = string
}
