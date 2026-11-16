variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "admin_group_name" {
  type    = string
  default = "CloudAdmins"
}

variable "accounts" {
  type    = map(string)
  default = {}
}

variable "developer_account_keys" {
  type        = list(string)
  default     = ["development"]
  description = "Keys of var.accounts where the Developers group gets DeveloperAccess."
}

variable "custom_permission_sets" {
  description = "Map of custom permission sets to create. Each key becomes the permission set name."
  type = map(object({
    description      = string
    session_duration = optional(string, "PT8H")
    managed_policies = optional(list(string), [])
    inline_policy    = optional(string, null)
    tags             = optional(map(string), {})
  }))
  default = {}
}
