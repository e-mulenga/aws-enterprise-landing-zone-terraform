variable "organization_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "security_account_email" {
  type = string
}

variable "logging_account_email" {
  type = string
}

variable "shared_services_account_email" {
  type = string
}

variable "development_account_email" {
  type = string
}

variable "production_account_email" {
  type = string
}

variable "security_ou_id" {
  type    = string
  default = ""
}

variable "infrastructure_ou_id" {
  type    = string
  default = ""
}

variable "development_ou_id" {
  type    = string
  default = ""
}

variable "production_ou_id" {
  type    = string
  default = ""
}

variable "ou_ids" {
  type        = map(string)
  default     = {}
  description = "OU IDs by key (security, infrastructure, audit, sandbox, workloads, development, production)."
}

variable "organization_id" {
  type        = string
  description = "AWS Organization ID."
}

variable "additional_accounts" {
  description = "Extra member accounts to vend, by account name."
  type = map(object({
    email        = string
    ou           = string
    account_type = optional(string, "workload")
    environment  = optional(string, "dev")
    tags         = optional(map(string), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for a in var.additional_accounts : contains(["security", "infrastructure", "audit", "sandbox", "workloads", "development", "production"], a.ou)])
    error_message = "ou must be one of security, infrastructure, audit, sandbox, workloads, development, production."
  }
}
