variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "VPC whose DNS queries are logged and filtered (from the networking module)."
}

variable "vpc_name" {
  type        = string
  default     = "primary"
  description = "Short name used in resource names, for example primary or dr."
}

variable "enable_query_logging" {
  type    = bool
  default = true
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "CMK for the log group. null = CloudWatch default encryption. A CMK must trust logs.<region>.amazonaws.com."
}

variable "blocked_domains" {
  type        = list(string)
  default     = []
  description = "Domains blocked with NXDOMAIN, for example [\"*.example-bad.com.\"]. Empty = no DNS Firewall resources."
}
