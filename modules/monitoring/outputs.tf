output "dashboard_name" {
  value = aws_cloudwatch_dashboard.main.dashboard_name
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "findings_log_group_name" {
  description = "Log group that receives GuardDuty, Security Hub and Config events."
  value       = one(aws_cloudwatch_log_group.findings[*].name)
}
