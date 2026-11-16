output "cur_bucket_name" {
  description = "Bucket that receives the Cost and Usage Report (us-east-1)."
  value       = aws_s3_bucket.cur.id
}

output "cur_report_name" {
  value = aws_cur_report_definition.daily.report_name
}
