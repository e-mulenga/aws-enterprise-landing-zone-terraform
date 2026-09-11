# ============================================================
# Module: kms — Customer-Managed KMS Keys
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name
}

# ---- CloudTrail Key -----------------------------------------
resource "aws_kms_key" "cloudtrail" {
  description             = "CMK for CloudTrail log encryption — ${var.organization_name} ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = var.key_rotation_enabled
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudTrailEncrypt"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = ["kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:${local.partition}:cloudtrail:*:${var.management_account_id}:trail/*"
          }
        }
      },
      {
        Sid    = "AllowLoggingAccountDecrypt"
        Effect = "Allow"
        Principal = { AWS = "arn:${local.partition}:iam::${var.logging_account_id}:root" }
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = "*"
      }
    ]
  })

  tags = { Name = "${var.organization_name}-${var.environment}-cloudtrail-key" }
}

resource "aws_kms_alias" "cloudtrail" {
  name          = "alias/${var.organization_name}-${var.environment}-cloudtrail"
  target_key_id = aws_kms_key.cloudtrail.key_id
}

# ---- Config Key ---------------------------------------------
resource "aws_kms_key" "config" {
  description             = "CMK for AWS Config encryption — ${var.organization_name} ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = var.key_rotation_enabled

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowConfigService"
        Effect = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = "*"
      }
    ]
  })

  tags = { Name = "${var.organization_name}-${var.environment}-config-key" }
}

resource "aws_kms_alias" "config" {
  name          = "alias/${var.organization_name}-${var.environment}-config"
  target_key_id = aws_kms_key.config.key_id
}

# ---- GuardDuty Key ------------------------------------------
resource "aws_kms_key" "guardduty" {
  description             = "CMK for GuardDuty findings encryption — ${var.organization_name} ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = var.key_rotation_enabled

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowGuardDutyService"
        Effect = "Allow"
        Principal = { Service = "guardduty.amazonaws.com" }
        Action   = ["kms:GenerateDataKey"]
        Resource = "*"
      }
    ]
  })

  tags = { Name = "${var.organization_name}-${var.environment}-guardduty-key" }
}

resource "aws_kms_alias" "guardduty" {
  name          = "alias/${var.organization_name}-${var.environment}-guardduty"
  target_key_id = aws_kms_key.guardduty.key_id
}

# ---- Backup Key ---------------------------------------------
resource "aws_kms_key" "backup" {
  description             = "CMK for AWS Backup encryption — ${var.organization_name} ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = var.key_rotation_enabled

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = { Name = "${var.organization_name}-${var.environment}-backup-key" }
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.organization_name}-${var.environment}-backup"
  target_key_id = aws_kms_key.backup.key_id
}
