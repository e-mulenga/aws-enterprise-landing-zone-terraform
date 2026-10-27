# ============================================================
# Module: backup - AWS Backup (daily / weekly / monthly + cross-region copy)
# ============================================================
# Primary vault : af-south-1  (default provider)
# DR vault      : eu-west-1   (provider alias aws.dr), only if cross_region_copy_enabled
#
# Cost: an empty vault, the plan, the IAM role and the tag-based selection are
# free. Charges start only when a resource is tagged BackupEnabled=true and
# recovery points are stored. Dev/test therefore keep short retention, no cold
# storage, no cross-region copy and no vault lock; prod turns them on.
# ============================================================

resource "aws_iam_role" "backup" {
  name = "${var.organization_name}-${var.environment}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup_service" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# ---- Primary vault ------------------------------------------------------
resource "aws_backup_vault" "main" {
  name        = "${var.organization_name}-${var.environment}-backup-vault"
  kms_key_arn = var.kms_key_arn # null = aws/backup AWS managed key

  tags = { Name = "${var.organization_name}-${var.environment}-backup-vault" }

  lifecycle {
    prevent_destroy = true
  }
}

# ---- DR vault in the second region ------------------------------------
resource "aws_backup_vault" "dr" {
  count    = var.cross_region_copy_enabled ? 1 : 0
  provider = aws.dr

  name        = "${var.organization_name}-${var.environment}-backup-vault-dr"
  kms_key_arn = var.dr_kms_key_arn # null = aws/backup in the DR region

  tags = { Name = "${var.organization_name}-${var.environment}-backup-vault-dr" }

  lifecycle {
    prevent_destroy = true
  }
}

# ---- Vault Lock (prod only) --------------------------------------------
# Compliance-mode lock. After the cooling-off period it is IMMUTABLE: the vault
# and its recovery points cannot be deleted until retention expires. Never
# enable it in dev or test.
resource "aws_backup_vault_lock_configuration" "locked" {
  count = var.enable_vault_lock ? 1 : 0

  backup_vault_name   = aws_backup_vault.main.name
  min_retention_days  = var.vault_lock_min_retention_days
  changeable_for_days = var.vault_lock_changeable_for_days
}

# ---- Plan ---------------------------------------------------------------
resource "aws_backup_plan" "main" {
  name = "${var.organization_name}-${var.environment}-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)" # 02:00 UTC daily

    lifecycle {
      cold_storage_after = var.enable_cold_storage ? var.cold_storage_after_days : null
      delete_after       = var.daily_retention_days
    }

    dynamic "copy_action" {
      for_each = var.cross_region_copy_enabled ? [1] : []
      content {
        destination_vault_arn = aws_backup_vault.dr[0].arn
        lifecycle {
          delete_after = var.dr_copy_retention_days
        }
      }
    }
  }

  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 ? * 1 *)" # 03:00 UTC every Sunday

    lifecycle {
      cold_storage_after = var.enable_cold_storage ? var.cold_storage_after_days : null
      delete_after       = var.weekly_retention_days
    }
  }

  dynamic "rule" {
    for_each = var.monthly_retention_days > 0 ? [1] : []
    content {
      rule_name         = "monthly-backup"
      target_vault_name = aws_backup_vault.main.name
      schedule          = "cron(0 4 1 * ? *)" # 04:00 UTC on the 1st

      lifecycle {
        cold_storage_after = var.enable_cold_storage ? var.cold_storage_after_days : null
        delete_after       = var.monthly_retention_days
      }

      dynamic "copy_action" {
        for_each = var.cross_region_copy_enabled ? [1] : []
        content {
          destination_vault_arn = aws_backup_vault.dr[0].arn
          lifecycle {
            delete_after = var.monthly_retention_days
          }
        }
      }
    }
  }

  tags = { Name = "${var.organization_name}-${var.environment}-backup-plan" }

  lifecycle {
    # AWS Backup rejects cold storage unless it is followed by 90+ days.
    precondition {
      condition     = !var.enable_cold_storage || var.daily_retention_days >= var.cold_storage_after_days + 90
      error_message = "With cold storage enabled, daily_retention_days must be at least cold_storage_after_days + 90."
    }
  }
}

resource "aws_backup_selection" "main" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.organization_name}-${var.environment}-backup-selection"
  plan_id      = aws_backup_plan.main.id

  # Opt-in by tag: nothing is backed up (or billed) until a resource is tagged.
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "BackupEnabled"
    value = "true"
  }
}
