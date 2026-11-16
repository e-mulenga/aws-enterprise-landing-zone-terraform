variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "resource_types" {
  type        = list(string)
  default     = ["ECR", "LAMBDA"]
  description = "What Inspector scans: EC2, ECR, LAMBDA, LAMBDA_CODE. ECR and Lambda suit this portfolio (container images and functions)."

  validation {
    condition     = alltrue([for t in var.resource_types : contains(["EC2", "ECR", "LAMBDA", "LAMBDA_CODE"], t)])
    error_message = "resource_types may only contain EC2, ECR, LAMBDA and LAMBDA_CODE."
  }
}

variable "organization_aware" {
  type        = bool
  default     = false
  description = "Auto-enable Inspector for member accounts (management or delegated administrator account only)."
}
