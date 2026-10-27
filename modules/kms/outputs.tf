# ---- Primary contract: the shared key catalogue -------------
# In dev/test: arn/key_id are null and alias_name is the AWS managed alias.
# In prod    : arn/key_id/alias_name point at the customer managed key.
output "shared_kms_keys" {
  description = "Catalogue of the five shared keys: rds, s3, backup, analytics, ai."
  value = {
    for name, _ in local.shared_keys : name => {
      strategy   = local.create_cmk ? "customer-managed" : "aws-managed"
      arn        = local.create_cmk ? aws_kms_key.shared[name].arn : null
      key_id     = local.create_cmk ? aws_kms_key.shared[name].key_id : null
      alias_name = local.create_cmk ? aws_kms_alias.shared[name].name : local.aws_managed_alias[name]
    }
  }
}

output "shared_ai_key_arn" {
  description = "ARN of shared-ai-key. null when AWS managed / AWS-owned keys are used."
  value       = local.create_cmk ? aws_kms_key.shared["ai"].arn : null
}

output "key_strategy" {
  description = "aws-managed or customer-managed."
  value       = local.create_cmk ? "customer-managed" : "aws-managed"
}

# ---- Backwards-compatible outputs used by the logging modules ----
# CloudTrail, Config and GuardDuty write to S3, so they use shared-s3-key.
output "cloudtrail_key_arn" {
  description = "Key for CloudTrail log delivery (shared-s3-key). null with AWS managed keys."
  value       = local.create_cmk ? aws_kms_key.shared["s3"].arn : null
}

output "cloudtrail_key_id" {
  description = "Key ID for CloudTrail log delivery. null with AWS managed keys."
  value       = local.create_cmk ? aws_kms_key.shared["s3"].key_id : null
}

output "config_key_arn" {
  description = "Key for Config delivery (shared-s3-key). null with AWS managed keys."
  value       = local.create_cmk ? aws_kms_key.shared["s3"].arn : null
}

output "guardduty_key_arn" {
  description = "Key for GuardDuty export (shared-s3-key). null with AWS managed keys."
  value       = local.create_cmk ? aws_kms_key.shared["s3"].arn : null
}

output "backup_key_arn" {
  description = "Key for AWS Backup vaults (shared-backup-key). null with AWS managed keys."
  value       = local.create_cmk ? aws_kms_key.shared["backup"].arn : null
}
