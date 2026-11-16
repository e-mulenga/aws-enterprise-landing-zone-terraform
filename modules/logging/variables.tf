variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "cloudtrail_bucket" {
  type        = string
  default     = ""
  description = "Name for the CloudTrail bucket when it is created. Not needed if existing_buckets.cloudtrail is set."
}

variable "existing_buckets" {
  type = object({
    cloudtrail  = optional(string)
    config      = optional(string)
    guardduty   = optional(string)
    access_logs = optional(string)
  })
  default     = {}
  description = <<-EOT
    Names of buckets that are ALREADY deployed. Any bucket named here is looked up
    (read-only) instead of created. Leave a key unset/null to have the module create it.
    Existing buckets must already carry the policy/encryption the services need.
  EOT
}

variable "s3_versioning_enabled" {
  type    = bool
  default = true
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "CMK ARN for bucket encryption. null = SSE-S3 (AWS managed), e.g. in dev."
}

variable "log_retention_days" {
  type        = number
  default     = 365
  description = "Kept for interface compatibility; not used by this module."
}

variable "archive_expiry_days" {
  type        = number
  default     = 2557
  description = "Days before CloudTrail and Config archive objects expire. The default keeps the previous 7 year behaviour; the root module passes log_archive_expiry_days."

  validation {
    condition     = var.archive_expiry_days >= 366
    error_message = "archive_expiry_days must be at least 366 because objects move to Glacier after 365 days."
  }
}

variable "access_log_expiry_days" {
  type        = number
  default     = 90
  description = "Days before S3 access logs and GuardDuty exports expire."

  validation {
    condition     = var.access_log_expiry_days >= 1
    error_message = "access_log_expiry_days must be at least 1."
  }
}

variable "log_archive_expiry_days" {
  type        = number
  description = "Days before CloudTrail/Config archive objects expire. Lower = cheaper. Raise it only if a regulation requires longer retention."
  default     = 730
}

variable "organization_id" {
  type        = string
  description = "AWS Organizations ID (o-xxxxxxxxxx) used in the bucket policy conditions."
}

variable "management_account_id" {
  type        = string
  default     = ""
  description = "Kept for interface compatibility; not used by this module."
}
