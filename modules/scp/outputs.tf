output "baseline_guardrails_policy_id" {
  description = "Consolidated baseline guardrails SCP."
  value       = aws_organizations_policy.baseline_guardrails.id
}

output "region_restriction_policy_id" {
  description = "Region restriction SCP."
  value       = aws_organizations_policy.region_restriction.id
}

