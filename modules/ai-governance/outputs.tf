output "ai_audit_bucket_name" {
  description = "Bucket holding Bedrock invocation logs."
  value       = aws_s3_bucket.ai_audit.id
}

output "ai_audit_bucket_arn" {
  value = aws_s3_bucket.ai_audit.arn
}

output "bedrock_guardrails_enabled" {
  description = "true when the baseline guardrail is deployed."
  value       = var.enable_guardrail
}

output "guardrail_id" {
  description = "Baseline guardrail ID, or null when disabled."
  value       = one(aws_bedrock_guardrail.baseline[*].guardrail_id)
}

output "guardrail_arn" {
  value = one(aws_bedrock_guardrail.baseline[*].guardrail_arn)
}

output "guardrail_version" {
  description = "Published guardrail version to pass to applications."
  value       = one(aws_bedrock_guardrail_version.baseline[*].version)
}

output "approved_models_policy_arn" {
  description = "IAM policy that restricts Bedrock to approved models."
  value       = aws_iam_policy.approved_models.arn
}
