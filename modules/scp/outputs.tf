output "baseline_guardrails_policy_id" {
  description = "Consolidated baseline guardrails SCP."
  value       = aws_organizations_policy.baseline_guardrails.id
}

output "region_restriction_policy_id" {
  description = "Region restriction SCP."
  value       = aws_organizations_policy.region_restriction.id
}

output "ou_policy_ids" {
  description = "IDs of the per-OU SCPs, by policy name."
  value       = { for k, p in aws_organizations_policy.ou : k => p.id }
}
