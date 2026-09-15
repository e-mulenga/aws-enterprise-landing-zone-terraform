variable "environment" { type = string }
variable "organization_name" { type = string }
variable "admin_group_name" {
  type    = string
  default = "CloudAdmins"
}
variable "accounts" {
  type    = map(string)
  default = {}
}
