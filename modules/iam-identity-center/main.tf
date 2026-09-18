# ============================================================
# Module: iam-identity-center — AWS IAM Identity Center (SSO)
# ============================================================

data "aws_ssoadmin_instances" "main" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
}

# ---- Permission Sets ----------------------------------------
resource "aws_ssoadmin_permission_set" "administrator" {
  name             = "AdministratorAccess"
  description      = "Full administrator access — break-glass / platform engineering only."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT2H"

  tags = { Purpose = "admin" }
}

resource "aws_ssoadmin_managed_policy_attachment" "administrator" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_permission_set" "read_only" {
  name             = "ReadOnlyAccess"
  description      = "Read-only access for auditors and senior developers."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = { Purpose = "readonly" }
}

resource "aws_ssoadmin_managed_policy_attachment" "read_only" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.read_only.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_ssoadmin_permission_set" "developer" {
  name             = "DeveloperAccess"
  description      = "Scoped developer access — compute, storage, messaging."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = { Purpose = "developer" }
}

resource "aws_ssoadmin_permission_set_inline_policy" "developer" {
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DeveloperCompute"
        Effect = "Allow"
        Action = [
          "ec2:Describe*", "ec2:RunInstances", "ec2:StartInstances",
          "ec2:StopInstances", "ec2:TerminateInstances",
          "s3:GetObject", "s3:PutObject", "s3:ListBucket",
          "lambda:*", "logs:*", "cloudwatch:*",
          "sqs:*", "sns:Publish",
          "ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn
}

resource "aws_ssoadmin_permission_set" "security_auditor" {
  name             = "SecurityAuditorAccess"
  description      = "Security auditor — read-only security service access."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H"

  tags = { Purpose = "security-audit" }
}

resource "aws_ssoadmin_managed_policy_attachment" "security_auditor" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_auditor.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

# ---- Groups -------------------------------------------------
resource "aws_identitystore_group" "cloud_admins" {
  display_name      = var.admin_group_name
  description       = "Cloud platform administrators."
  identity_store_id = local.identity_store_id
}

resource "aws_identitystore_group" "developers" {
  display_name      = "Developers"
  description       = "Application developers."
  identity_store_id = local.identity_store_id
}

resource "aws_identitystore_group" "security_auditors" {
  display_name      = "SecurityAuditors"
  description       = "Security and compliance auditors."
  identity_store_id = local.identity_store_id
}

# ---- Account Assignments ------------------------------------
# Admins → all accounts
resource "aws_ssoadmin_account_assignment" "admin_assignments" {
  for_each = var.accounts

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn
  principal_id       = aws_identitystore_group.cloud_admins.group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}

# ---- CloudTrail ------------------------------------

resource "aws_cloudtrail" "main" {
  name           = "my-trail"
  s3_bucket_name = aws_s3_bucket.trail_bucket.id
  sns_topic_name = aws_sns_topic.trail_notifications.arn
}