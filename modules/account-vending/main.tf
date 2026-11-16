# ============================================================
# Module: account-vending — AWS Organisations Account Factory
# ============================================================

resource "aws_organizations_account" "logging" {
  name                       = "${var.environment}-logging"
  email                      = var.logging_account_email
  iam_user_access_to_billing = "DENY"
  parent_id                  = var.security_ou_id
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
  name                       = "development"
  email                      = var.development_account_email
  iam_user_access_to_billing = "DENY"
  parent_id                  = var.development_ou_id
  role_name                  = "OrganizationAccountAccessRole"

  tags = {
    AccountType = "development"
    Environment = "dev"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [email, name]
  }
}

resource "aws_organizations_account" "production" {
  name                       = "production"
  email                      = var.production_account_email
  iam_user_access_to_billing = "DENY"
  parent_id                  = var.production_ou_id
  role_name                  = "OrganizationAccountAccessRole"

  tags = {
    AccountType = "production"
    Environment = "prod"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [email, name]
  }
}

# ---- Additional accounts (vending) ----------------------------
# One entry creates one member account in the chosen OU. Accounts cannot be deleted through Terraform,
# so every entry is protected from destroy.
resource "aws_organizations_account" "additional" {
  for_each = var.additional_accounts

  name                       = each.key
  email                      = each.value.email
  iam_user_access_to_billing = "DENY"
  parent_id                  = var.ou_ids[each.value.ou]
  role_name                  = "OrganizationAccountAccessRole"

  tags = merge(
    { AccountType = each.value.account_type, Environment = each.value.environment },
    each.value.tags
  )

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [email, name]
  }
}
