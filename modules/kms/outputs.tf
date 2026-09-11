output "cloudtrail_key_arn" {
  value     = aws_kms_key.cloudtrail.arn
  sensitive = true
}

output "cloudtrail_key_id" {
  value = aws_kms_key.cloudtrail.key_id
}

output "config_key_arn" {
  value     = aws_kms_key.config.arn
  sensitive = true
}

output "guardduty_key_arn" {
  value     = aws_kms_key.guardduty.arn
  sensitive = true
}

output "backup_key_arn" {
  value     = aws_kms_key.backup.arn
  sensitive = true
}
