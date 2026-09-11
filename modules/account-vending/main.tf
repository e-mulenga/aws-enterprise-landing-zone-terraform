# ============================================================
# Module: account-vending — AWS Organisations Account Factory
# ============================================================

resource "aws_organizations_account" "security" {
  name                       = "${var.environment}-security"
  email                      = var.security_account_email
  iam_user_access_to_billing = "DENY"
  parent_id                  = var.security_ou_id
  role_name                  = "OrganizationAccountAccessRole"

  tags = {
    AccountType = "security"
    Environment = var.environment
  }

  lifecycle {
    # Accounts cannot be deleted via Terraform — prevent accidental destroy
    prevent_destroy = true
    ignore_changes  = [email, name]
  }
}

resource "aws_organizations_account" "logging" {
  name                       = "${var.environment}-logging"
  email                      = var.logging_account_email
  iam_user_access_to_billing = "DENY"
  parent_id                  = var.infrastructure_ou_id
  role_name                  = "OrganizationAccountAccessRole"

  tags = {
    AccountType = "logging"
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [email, name]
  }
}

resource "aws_organizations_account" "shared_services" {
  name                       = "${var.environment}-shared-services"
  email                      = var.shared_services_account_email
  iam_user_access_to_billing = "DENY"
  parent_id                  = var.infrastructure_ou_id
  role_name                  = "OrganizationAccountAccessRole"

  tags = {
    AccountType = "shared-services"
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [email, name]
  }
}

resource "aws_organizations_account" "development" {
  name                       = "workload-development"
  email                      = var.development_account_email
  iam_user_access_to_billing = "DENY"
  parent_id                  = var.workloads_dev_ou_id
  role_name                  = "OrganizationAccountAccessRole"

  tags = {
    AccountType = "workload"
    Environment = "dev"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [email, name]
  }
}

resource "aws_organizations_account" "production" {
  name                       = "workload-production"
  email                      = var.production_account_email
  iam_user_access_to_billing = "DENY"
  parent_id                  = var.workloads_prod_ou_id
  role_name                  = "OrganizationAccountAccessRole"

  tags = {
    AccountType = "workload"
    Environment = "prod"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [email, name]
  }
}
