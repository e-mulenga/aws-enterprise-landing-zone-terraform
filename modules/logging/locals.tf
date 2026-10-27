locals {
  existing = var.existing_buckets

  create_cloudtrail  = local.existing.cloudtrail == null
  create_config      = local.existing.config == null
  create_guardduty   = local.existing.guardduty == null
  create_access_logs = local.existing.access_logs == null

  # AWS managed / default encryption when no CMK is supplied (dev).
  use_kms       = var.kms_key_arn != null
  sse_algorithm = local.use_kms ? "aws:kms" : "AES256"
}

# ---- Resolved bucket details (created OR existing) ----------
# concat() joins the two single-or-empty lists and one() picks the only
# element, so each local is the same shape in both modes.
locals {
  buckets = {
    cloudtrail = {
      name   = one(concat(data.aws_s3_bucket.cloudtrail[*].bucket, aws_s3_bucket.cloudtrail[*].bucket))
      arn    = one(concat(data.aws_s3_bucket.cloudtrail[*].arn, aws_s3_bucket.cloudtrail[*].arn))
      region = one(concat(data.aws_s3_bucket.cloudtrail[*].region, aws_s3_bucket.cloudtrail[*].region))
      source = local.create_cloudtrail ? "created" : "existing"
    }
    config = {
      name   = one(concat(data.aws_s3_bucket.config[*].bucket, aws_s3_bucket.config[*].bucket))
      arn    = one(concat(data.aws_s3_bucket.config[*].arn, aws_s3_bucket.config[*].arn))
      region = one(concat(data.aws_s3_bucket.config[*].region, aws_s3_bucket.config[*].region))
      source = local.create_config ? "created" : "existing"
    }
    guardduty = {
      name   = one(concat(data.aws_s3_bucket.guardduty[*].bucket, aws_s3_bucket.guardduty[*].bucket))
      arn    = one(concat(data.aws_s3_bucket.guardduty[*].arn, aws_s3_bucket.guardduty[*].arn))
      region = one(concat(data.aws_s3_bucket.guardduty[*].region, aws_s3_bucket.guardduty[*].region))
      source = local.create_guardduty ? "created" : "existing"
    }
    access_logs = {
      name   = one(concat(data.aws_s3_bucket.access_logs[*].bucket, aws_s3_bucket.access_logs[*].bucket))
      arn    = one(concat(data.aws_s3_bucket.access_logs[*].arn, aws_s3_bucket.access_logs[*].arn))
      region = one(concat(data.aws_s3_bucket.access_logs[*].region, aws_s3_bucket.access_logs[*].region))
      source = local.create_access_logs ? "created" : "existing"
    }
  }
}
