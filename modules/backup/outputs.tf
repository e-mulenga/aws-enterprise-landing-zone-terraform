output "vault_arn" {
  value = aws_backup_vault.main.arn
}

output "vault_name" {
  value = aws_backup_vault.main.name
}

output "dr_vault_arn" {
  description = "DR vault ARN in the second region, or null when cross-region copy is off."
  value       = one(aws_backup_vault.dr[*].arn)
}

output "dr_vault_name" {
  value = one(aws_backup_vault.dr[*].name)
}

output "backup_plan_id" {
  value = aws_backup_plan.main.id
}

output "backup_role_arn" {
  value = aws_iam_role.backup.arn
}
