variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "s3_bucket_name" {
  type        = string
  description = "Delivery bucket name. Take it from the logging module output (created or existing bucket)."
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "CMK ARN. null = AWS managed / default encryption (e.g. dev)."
}

variable "log_retention_days" {
  type    = number
  default = 365
}

variable "is_organization_trail" {
  type    = bool
  default = true
}

variable "data_events_enabled" {
  type        = bool
  default     = false
  description = "Record S3 object and Lambda data events. Billed per event; keep false in dev."
}

variable "insights_enabled" {
  type        = bool
  default     = false
  description = "Enable CloudTrail Insights (billed per event analysed). Prod only."
}
