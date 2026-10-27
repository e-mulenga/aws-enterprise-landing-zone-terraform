variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "shared-ai-key ARN (prod). null = SSE-S3 for the audit bucket and the AWS-owned key for the guardrail."
}

variable "audit_retention_days" {
  type        = number
  default     = 30
  description = "Days AI audit logs are kept. Short in dev/test to limit storage cost; raise in prod."
}

variable "enable_invocation_logging" {
  type        = bool
  default     = true
  description = "Turn on Bedrock model invocation logging to the audit bucket (one configuration per Region)."
}

variable "enable_guardrail" {
  type        = bool
  default     = true
  description = "Create the baseline guardrail. No standing charge."
}

variable "approved_model_arns" {
  type        = list(string)
  description = "Foundation model ARNs workloads may use. Narrow this to the exact models you approve."
  default = [
    "arn:aws:bedrock:*::foundation-model/anthropic.*",
    "arn:aws:bedrock:*::foundation-model/amazon.titan-*",
    "arn:aws:bedrock:*::foundation-model/amazon.nova-*",
  ]
}
