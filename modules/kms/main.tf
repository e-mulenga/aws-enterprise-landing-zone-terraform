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
