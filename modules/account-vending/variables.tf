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
