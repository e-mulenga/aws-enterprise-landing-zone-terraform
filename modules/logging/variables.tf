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

variable "organization_id" {
  type        = string
  description = "AWS Organizations ID (o-xxxxxxxxxx) used in the bucket policy conditions."
}

variable "management_account_id" {
  type        = string
  default     = ""
  description = "Kept for interface compatibility; not used by this module."
}
