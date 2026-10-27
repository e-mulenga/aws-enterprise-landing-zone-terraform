output "ecr_repository_urls" {
  description = "Repository URLs by short name (shared-platform, shared-applications, shared-devsecops)."
  value       = { for k, r in aws_ecr_repository.shared : k => r.repository_url }
}

output "ecr_repository_arns" {
  description = "Repository ARNs by short name."
  value       = { for k, r in aws_ecr_repository.shared : k => r.arn }
}
