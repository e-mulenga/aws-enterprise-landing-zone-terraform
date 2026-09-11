variable "environment"           { type = string }
variable "organization_name"     { type = string }
variable "s3_bucket_name"        { type = string }
variable "kms_key_arn"           { type = string }
variable "log_retention_days" {
  type    = number
  default = 365
}
variable "is_organization_trail" {
  type    = bool
  default = true
}
