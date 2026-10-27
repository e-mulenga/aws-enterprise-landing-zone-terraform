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

variable "enabled" {
  type    = bool
  default = true
}

variable "recording_frequency" {
  type        = string
  default     = "CONTINUOUS"
  description = "CONTINUOUS or DAILY."

  validation {
    condition     = contains(["CONTINUOUS", "DAILY"], var.recording_frequency)
    error_message = "recording_frequency must be CONTINUOUS or DAILY."
  }
}

variable "rule_set" {
  type        = string
  default     = "core"
  description = "core = 9 essential managed rules (dev). full = all 20 managed rules (prod)."

  validation {
    condition     = contains(["core", "full"], var.rule_set)
    error_message = "rule_set must be core or full."
  }
}
