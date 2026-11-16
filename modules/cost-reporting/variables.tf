variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "retention_days" {
  type        = number
  default     = 395
  description = "Days report files are kept (13 months covers year-on-year comparison)."

  validation {
    condition     = var.retention_days >= 31
    error_message = "retention_days must be at least 31."
  }
}
