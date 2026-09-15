output "cloudtrail_bucket_name" { value = aws_s3_bucket.cloudtrail.bucket }
output "cloudtrail_bucket_arn" { value = aws_s3_bucket.cloudtrail.arn }
output "config_bucket_name" { value = aws_s3_bucket.config.bucket }
output "guardduty_bucket_name" { value = aws_s3_bucket.guardduty.bucket }
output "access_logs_bucket_arn" { value = aws_s3_bucket.access_logs.arn }
