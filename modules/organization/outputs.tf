output "organization_id" {
  description = "The ID of the AWS Organisation."
  value       = aws_organizations_organization.main.id
}

output "organization_arn" {
  description = "The ARN of the AWS Organisation."
  value       = aws_organizations_organization.main.arn
}

output "master_account_id" {
  description = "The account ID of the management (master) account."
  value       = aws_organizations_organization.main.master_account_id
}

output "root_id" {
  description = "The root ID of the Organisation."
  value       = aws_organizations_organization.main.roots[0].id
}

output "security_ou_id" {
  description = "Organisational Unit ID for Security accounts."
  value       = aws_organizations_organizational_unit.security.id
}

output "workloads_dev_ou_id" {
  description = "Organisational Unit ID for Development workloads."
  value       = aws_organizations_organizational_unit.workloads_dev.id
}

output "workloads_prod_ou_id" {
  description = "Organisational Unit ID for Production workloads."
  value       = aws_organizations_organizational_unit.workloads_prod.id
}

output "infrastructure_ou_id" {
  description = "Infrastructure OU ID"
  value       = aws_organizations_organizational_unit.infrastructure.id
}