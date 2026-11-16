output "tag_policy_id" {
  description = "ID of the organisation tag policy."
  value       = aws_organizations_policy.tags.id
}
