output "detector_id" {
  description = "GuardDuty detector ID (created or existing)."
  value       = local.detector_id
}

output "alerts_topic_arn" {
  value = aws_sns_topic.guardduty_alerts.arn
}
