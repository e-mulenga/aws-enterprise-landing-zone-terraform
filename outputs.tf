# ============================================================
# AWS Enterprise Landing Zone — Root Outputs
# ============================================================

output "organization_id" {
  description = "AWS Organisation ID."
  value       = module.organization.organization_id
}

output "organization_arn" {
  description = "AWS Organisation ARN."
  value       = module.organization.organization_arn
}

output "security_account_id" {
  description = "Account ID of the Security account."
  value       = module.accounts.security_account_id
}

output "logging_account_id" {
  description = "Account ID of the Logging account."
  value       = module.accounts.logging_account_id
}

output "shared_services_account_id" {
  description = "Account ID of the Shared Services account."
  value       = module.accounts.shared_services_account_id
}

output "development_account_id" {
  description = "Account ID of the Development account."
  value       = module.accounts.development_account_id
}

output "production_account_id" {
  description = "Account ID of the Production account."
  value       = module.accounts.production_account_id
}

output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket storing CloudTrail logs."
  value       = module.logging.cloudtrail_bucket_name
}

output "cloudtrail_trail_arn" {
  description = "ARN of the organisation CloudTrail trail."
  value       = module.cloudtrail.trail_arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID in the Security account."
  value       = module.guardduty.detector_id
}

output "kms_cloudtrail_key_arn" {
  description = "ARN of the KMS key encrypting CloudTrail logs."
  value       = module.kms.cloudtrail_key_arn
  sensitive   = true
}

output "monitoring_dashboard_name" {
  description = "Name of the CloudWatch dashboard."
  value       = module.monitoring.dashboard_name
}
