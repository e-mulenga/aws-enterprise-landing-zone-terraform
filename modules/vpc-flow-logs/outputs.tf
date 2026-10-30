output "flow_log_ids" {
  description = "IDs of the flow log resources this module created."
  value       = concat(aws_flow_log.cloudwatch[*].id, aws_flow_log.s3[*].id)
}

output "log_group_name" {
  description = "CloudWatch Log group name. null when destination is s3 only."
  value       = try(aws_cloudwatch_log_group.flow_logs[0].name, null)
}

output "log_group_arn" {
  description = "CloudWatch Log group ARN. null when destination is s3 only."
  value       = try(aws_cloudwatch_log_group.flow_logs[0].arn, null)
}

output "s3_bucket_name" {
  description = "Central access-logs bucket this module delivers to. null when destination is cloudwatch only."
  value       = local.want_s3 ? var.access_logs_bucket_name : null
}

output "s3_key_prefix" {
  description = "S3 key prefix flow logs are delivered under. null when destination is cloudwatch only."
  value       = local.want_s3 ? var.s3_key_prefix : null
}

output "destination" {
  value = var.destination
}
