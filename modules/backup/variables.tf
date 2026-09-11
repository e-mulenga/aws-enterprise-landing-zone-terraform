variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "retention_days" {
  type    = number
  default = 35
}

variable "kms_key_arn" {
  type = string
}
