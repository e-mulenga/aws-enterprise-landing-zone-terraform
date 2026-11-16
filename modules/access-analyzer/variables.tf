variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "analyzer_type" {
  type        = string
  default     = "ORGANIZATION"
  description = "ORGANIZATION (management or delegated administrator account) or ACCOUNT."

  validation {
    condition     = contains(["ORGANIZATION", "ACCOUNT"], var.analyzer_type)
    error_message = "analyzer_type must be ORGANIZATION or ACCOUNT."
  }
}
