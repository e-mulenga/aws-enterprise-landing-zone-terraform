output "trail_arn" { value = aws_cloudtrail.org_trail.arn }
output "trail_name" { value = aws_cloudtrail.org_trail.name }
output "log_group_name" { value = aws_cloudwatch_log_group.cloudtrail.name }
output "log_group_arn" { value = aws_cloudwatch_log_group.cloudtrail.arn }
