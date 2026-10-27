variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "create_provider" {
  type        = bool
  default     = false
  description = "false = the OIDC provider already exists, look it up. true = create it (only one per account)."
}

variable "roles" {
  description = "Optional GitHub Actions roles. subjects are OIDC sub claims, e.g. repo:OWNER/REPO:ref:refs/heads/main."
  type = map(object({
    description          = optional(string, "GitHub Actions role")
    subjects             = list(string)
    policy_arns          = optional(list(string), [])
    max_session_duration = optional(number, 3600)
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for r in var.roles : [for s in r.subjects : startswith(s, "repo:") && s != "repo:*" && !startswith(s, "repo:*")]
    ]))
    error_message = "Every subject must start with repo:OWNER/REPO and must not be a wildcard for all repositories."
  }
}
