variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "repositories" {
  type        = list(string)
  default     = ["shared-platform", "shared-applications", "shared-devsecops"]
  description = "Repository names. Each becomes <organization>-<environment>/<name>."
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "CMK for image encryption. null = AES256 (AWS managed, no cost)."
}

variable "keep_last_images" {
  type        = number
  default     = 20
  description = "Number of most recent images kept per repository."
}

variable "organization_id" {
  type        = string
  default     = ""
  description = "If set, any account in this AWS Organization may pull images."
}
