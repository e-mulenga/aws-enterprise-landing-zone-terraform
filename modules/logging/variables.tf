variable "environment"           { type = string }
variable "organization_name"     { type = string }
variable "cloudtrail_bucket"     { type = string }
variable "s3_versioning_enabled" {
  type    = bool
  default = true
}
variable "kms_key_arn"           { type = string }
variable "log_retention_days" {
  type    = number
  default = 365
}
variable "organization_id"       { type = string }
variable "management_account_id" { type = string }
