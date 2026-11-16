variable "organization_id" {
  type = string
}

variable "organization_root_id" {
  type    = string
  default = ""
}

variable "allowed_regions" {
  type = list(string)
}

variable "environment" {
  type = string
}

variable "ou_policies" {
  description = "Per-OU SCPs keyed by policy name. Each entry specifies a description, the target OU IDs, and a JSON-encoded array of IAM policy statements."
  type = map(object({
    description     = string
    target_ou_ids   = list(string)
    statements_json = string
  }))
  default = {}
}
