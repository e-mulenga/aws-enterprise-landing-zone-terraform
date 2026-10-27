variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "domain_name" {
  type        = string
  default     = ""
  description = "Existing Route 53 domain / public hosted zone name (for example example.com). Empty = DNS foundation disabled."
}

variable "create_certificates" {
  type        = bool
  default     = true
  description = "Request wildcard ACM certificates (free) validated in the existing zone."
}

variable "create_cloudfront_certificate" {
  type        = bool
  default     = true
  description = "Also request the us-east-1 certificate that CloudFront requires."
}
