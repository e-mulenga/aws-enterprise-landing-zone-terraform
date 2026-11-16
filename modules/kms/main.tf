# ============================================================
# Module: kms - Enterprise key strategy
# ============================================================
# dev / test  : use_aws_managed_keys = true  -> NO KMS resources, USD 0.
#               Workloads use the AWS managed keys (aws/s3, aws/rds, ...).
# prod        : use_aws_managed_keys = false -> five shared customer managed
#               keys (rds, s3, backup, analytics, ai), rotation on.
#
# Cost of the prod strategy: USD 1 per key per month (5 keys = USD 5/month)
# plus request charges, which are negligible at portfolio volumes.
# ============================================================

resource "aws_kms_key" "shared" {
  for_each = local.create_cmk ? local.shared_keys : {}

  description             = "${each.value} - ${var.organization_name} ${var.environment}"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.key_rotation_enabled
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "EnableRootAccess"
          Effect    = "Allow"
          Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
          Action    = "kms:*"
          Resource  = "*"
        }
      ],
      local.extra_statements[each.key]
    )
  })

  tags = {
    Name    = "${var.organization_name}-${var.environment}-shared-${each.key}-key"
    Purpose = "shared-${each.key}"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "shared" {
  for_each = aws_kms_key.shared

  name          = "alias/${var.organization_name}-${var.environment}-shared-${each.key}"
  target_key_id = each.value.key_id
}

# ---- eu-west-1 replicas (opt-in) ------------------------------
# Same key material in the DR Region, so DR copies of backups and data can be decrypted there.
# Each replica bills USD 1 per month like any other key. Enabling this on existing keys replaces them
# because multi_region cannot be changed in place.
resource "aws_kms_replica_key" "shared" {
  for_each = local.create_cmk && var.dr_replicas_enabled ? local.shared_keys : {}
  provider = aws.dr

  description             = "Replica of ${each.value} - ${var.organization_name} ${var.environment}"
  primary_key_arn         = aws_kms_key.shared[each.key].arn
  deletion_window_in_days = var.deletion_window_in_days

  tags = {
    Name    = "${var.organization_name}-${var.environment}-shared-${each.key}-key-replica"
    Purpose = "shared-${each.key}-replica"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "replica" {
  for_each = aws_kms_replica_key.shared
  provider = aws.dr

  name          = "alias/${var.organization_name}-${var.environment}-shared-${each.key}"
  target_key_id = each.value.key_id
}
