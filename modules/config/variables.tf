variable "environment" { type = string }
variable "organization_name" { type = string }
variable "s3_bucket_name" { type = string }
variable "kms_key_arn" { type = string }
variable "enabled" {
  type    = bool
  default = true
}
