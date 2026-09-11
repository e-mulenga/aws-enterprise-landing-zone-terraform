variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "key_rotation_enabled" {
  type    = bool
  default = true
}

variable "management_account_id" {
  type = string
}

variable "security_account_id" {
  type    = string
  default = ""
}

variable "logging_account_id" {
  type    = string
  default = ""
}
