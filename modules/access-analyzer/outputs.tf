output "analyzer_arn" {
  description = "ARN of the external access analyzer."
  value       = aws_accessanalyzer_analyzer.external.arn
}

output "analyzer_name" {
  value = aws_accessanalyzer_analyzer.external.analyzer_name
}
