# ============================================================
# Module: backup — AWS Backup (Organisation Policy)
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

resource "aws_backup_vault" "main" {
  name        = "${var.organization_name}-${var.environment}-backup-vault"
  kms_key_arn = var.kms_key_arn

  tags = { Name = "${var.organization_name}-${var.environment}-backup-vault" }
}

resource "aws_backup_vault_lock_configuration" "main" {
  backup_vault_name   = aws_backup_vault.main.name
  min_retention_days  = var.retention_days
  changeable_for_days = 3
}

resource "aws_backup_plan" "main" {
  name = "${var.organization_name}-${var.environment}-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)" # 02:00 UTC daily

    lifecycle {
      cold_storage_after = 35
      delete_after       = var.retention_days
    }

    copy_action {
      lifecycle {
        cold_storage_after = 30
        delete_after       = var.retention_days
      }
      destination_vault_arn = aws_backup_vault.main.arn
    }
  }

  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 ? * 1 *)" # 03:00 UTC every Sunday

    lifecycle {
      cold_storage_after = 90
      delete_after       = 365
    }
  }

  tags = { Name = "${var.organization_name}-${var.environment}-backup-plan" }
}

resource "aws_backup_selection" "main" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.organization_name}-${var.environment}-backup-selection"
  plan_id      = aws_backup_plan.main.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "BackupEnabled"
    value = "true"
  }
}
