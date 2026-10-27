# Original outputs (unchanged names) -------------------------
output "cloudtrail_bucket_name" {
  value = local.buckets.cloudtrail.name
}

output "cloudtrail_bucket_arn" {
  value = local.buckets.cloudtrail.arn
}

output "config_bucket_name" {
  value = local.buckets.config.name
}

output "guardduty_bucket_name" {
  value = local.buckets.guardduty.name
}

output "access_logs_bucket_arn" {
  value = local.buckets.access_logs.arn
}

# Added for consumers in other repos --------------------------
output "config_bucket_arn" {
  value = local.buckets.config.arn
}

output "guardduty_bucket_arn" {
  value = local.buckets.guardduty.arn
}

output "access_logs_bucket_name" {
  value = local.buckets.access_logs.name
}

output "buckets" {
  description = "Every log bucket with name, ARN, region and whether it was created or already existed."
  value       = local.buckets
}
