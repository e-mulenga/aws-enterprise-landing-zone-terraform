variable "organization_name" {
  description = "Organisation short name, used for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, test, prod)."
  type        = string
}

variable "region_name" {
  description = "Short label for the Region this VPC is in (e.g. af-south-1, eu-west-1). Used only for naming/tags so the primary and DR calls of this module don't collide."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC (from modules/networking in this same repo) to enable flow logs on."
  type        = string
}

variable "destination" {
  description = "Where flow logs are delivered: cloudwatch, s3, or both. s3 is the lowest-cost option (no per-GB ingestion charge); cloudwatch adds real-time metric-filter/alarm capability at a materially higher per-GB cost. See docs/vpc-flow-logs-cost-analysis.md."
  type        = string
  default     = "s3"

  validation {
    condition     = contains(["cloudwatch", "s3", "both"], var.destination)
    error_message = "destination must be one of: cloudwatch, s3, both."
  }
}

variable "traffic_type" {
  description = "ALL, ACCEPT, or REJECT. REJECT-only cuts log volume (and cost) substantially and is often enough for security monitoring (unexpected denied traffic); ALL is needed for network troubleshooting / full Athena analysis."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.traffic_type)
    error_message = "traffic_type must be one of: ALL, ACCEPT, REJECT."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Log group retention (only used when destination is cloudwatch or both)."
  type        = number
  default     = 30
}

variable "access_logs_bucket_name" {
  description = "Name of the existing central access-logs S3 bucket (modules/logging output) — this module never creates a bucket."
  type        = string
}

variable "access_logs_bucket_arn" {
  description = "ARN of the existing central access-logs S3 bucket."
  type        = string
}

variable "s3_key_prefix" {
  description = "S3 key prefix flow logs are delivered under, e.g. vpc-flow-logs/af-south-1/ (only used when destination is s3 or both)."
  type        = string
}

variable "kms_key_arn" {
  description = "Optional CMK ARN to encrypt the CloudWatch Log group. Null uses the default CloudWatch-managed encryption (no extra cost); set only in environments using customer-managed keys."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
