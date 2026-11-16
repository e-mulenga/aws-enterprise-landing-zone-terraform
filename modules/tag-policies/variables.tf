variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "organization_root_id" {
  type        = string
  description = "Root ID the policy is attached to."
}

variable "allowed_environment_values" {
  type        = list(string)
  default     = ["dev", "test", "prod", "shared"]
  description = "Values allowed for the Environment tag."
}

variable "enforced_for" {
  type        = list(string)
  default     = []
  description = "Resource types (for example ec2:instance) where non-compliant tagging is blocked. Empty = report only."
}
