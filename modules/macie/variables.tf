variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "finding_publishing_frequency" {
  type        = string
  default     = "SIX_HOURS"
  description = "FIFTEEN_MINUTES, ONE_HOUR or SIX_HOURS."

  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.finding_publishing_frequency)
    error_message = "finding_publishing_frequency must be FIFTEEN_MINUTES, ONE_HOUR or SIX_HOURS."
  }
}
