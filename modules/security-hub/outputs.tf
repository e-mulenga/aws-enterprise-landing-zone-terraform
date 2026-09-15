output "hub_arn" { value = aws_securityhub_account.main.id }
output "alerts_topic_arn" { value = aws_sns_topic.sechub_alerts.arn }
