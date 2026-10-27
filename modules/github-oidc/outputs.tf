output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider (created or existing)."
  value       = local.provider_arn
}

output "role_arns" {
  description = "ARNs of the optional GitHub Actions roles, by key."
  value       = { for k, r in aws_iam_role.github : k => r.arn }
}
