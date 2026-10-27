output "organization_id" {
  description = "The ID of the AWS Organisation."
  value       = data.aws_organizations_organization.main.id
}

output "organization_arn" {
  description = "The ARN of the AWS Organisation."
  value       = data.aws_organizations_organization.main.arn
}

output "master_account_id" {
  description = "The account ID of the management (master) account."
  value       = data.aws_organizations_organization.main.master_account_id
}

output "root_id" {
  description = "The root ID of the Organisation."
  value       = local.root_id
}

output "security_ou_id" {
  description = "Organisational Unit ID for Security accounts."
  value       = aws_organizations_organizational_unit.security.id
}

output "infrastructure_ou_id" {
  description = "Organisational Unit ID for Infrastructure / shared services."
  value       = aws_organizations_organizational_unit.infrastructure.id
}

output "audit_ou_id" {
  description = "Organisational Unit ID for Audit / log archive accounts."
  value       = aws_organizations_organizational_unit.audit.id
}

output "sandbox_ou_id" {
  description = "Organisational Unit ID for Sandbox accounts."
  value       = aws_organizations_organizational_unit.sandbox.id
}

output "workloads_ou_id" {
  description = "Organisational Unit ID for the Workloads parent OU."
  value       = aws_organizations_organizational_unit.workloads.id
}

output "development_ou_id" {
  description = "Organisational Unit ID for Development workloads (under Workloads)."
  value       = aws_organizations_organizational_unit.workloads_dev.id
}

output "production_ou_id" {
  description = "Organisational Unit ID for Production workloads (under Workloads)."
  value       = aws_organizations_organizational_unit.workloads_prod.id
}

output "ou_ids" {
  description = "All OU IDs in one map, for consumers."
  value = {
    security       = aws_organizations_organizational_unit.security.id
    infrastructure = aws_organizations_organizational_unit.infrastructure.id
    audit          = aws_organizations_organizational_unit.audit.id
    sandbox        = aws_organizations_organizational_unit.sandbox.id
    workloads      = aws_organizations_organizational_unit.workloads.id
    development    = aws_organizations_organizational_unit.workloads_dev.id
    production     = aws_organizations_organizational_unit.workloads_prod.id
  }
}
