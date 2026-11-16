output "sso_instance_arn" {
  value = local.sso_instance_arn
}

output "admin_group_id" {
  value = aws_identitystore_group.cloud_admins.group_id
}

output "administrator_perm_set_arn" {
  value = aws_ssoadmin_permission_set.administrator.arn
}

output "read_only_perm_set_arn" {
  value = aws_ssoadmin_permission_set.read_only.arn
}

output "developer_perm_set_arn" {
  value = aws_ssoadmin_permission_set.developer.arn
}

output "permission_set_arns" {
  description = "ARNs of every permission set, by name."
  value = merge(
    {
      AdministratorAccess   = aws_ssoadmin_permission_set.administrator.arn
      ReadOnlyAccess        = aws_ssoadmin_permission_set.read_only.arn
      DeveloperAccess       = aws_ssoadmin_permission_set.developer.arn
      SecurityAuditorAccess = aws_ssoadmin_permission_set.security_auditor.arn
    },
    { for k, p in aws_ssoadmin_permission_set.custom : k => p.arn }
  )
}
