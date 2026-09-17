output "security_account_id" { 
  value = aws_organizations_account.security.id 
}

output "logging_account_id" {
  value = aws_organizations_account.logging.id 
}

output "shared_services_account_id" { 
  value = aws_organizations_account.shared_services.id 
}

output "development_account_id" { 
  value = aws_organizations_account.development.id 
}

output "production_account_id" { 
  value = aws_organizations_account.production.id 
}

output "account_map" {
  description = "Map of account names to account IDs."
  value = {
    security        = aws_organizations_account.security.id
    logging         = aws_organizations_account.logging.id
    shared_services = aws_organizations_account.shared_services.id
    development     = aws_organizations_account.development.id
    production      = aws_organizations_account.production.id
  }
}
