output "sink_arn" {
  description = "ARN member accounts use as sink_identifier in aws_oam_link."
  value       = aws_oam_sink.central.arn
}
