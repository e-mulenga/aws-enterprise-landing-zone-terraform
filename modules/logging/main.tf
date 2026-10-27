# ============================================================
# Module: logging - Centralised Log Archive (Logging Account)
#
# Each of the four buckets is either
#   * CREATED  (default), or
#   * LOOKED UP when its name is given in var.existing_buckets
#     (already deployed, e.g. by another repo/stack).
#
# Either way the module outputs the same names/ARNs, so other repos can
# consume them without caring where the bucket came from.
# Existing buckets are only READ: this module never changes their policy,
# encryption or lifecycle.
# ============================================================

# ---- CloudTrail S3 Bucket -----------------------------------
resource "aws_s3_bucket" "cloudtrail" {
  count = local.create_cloudtrail ? 1 : 0

  bucket        = var.cloudtrail_bucket
  force_destroy = false

  tags = { Name = var.cloudtrail_bucket, Purpose = "cloudtrail-archive" }

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = var.cloudtrail_bucket != ""
      error_message = "cloudtrail_bucket must be set when existing_buckets.cloudtrail is null."
    }
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  count = local.create_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id
  versioning_configuration { status = var.s3_versioning_enabled ? "Enabled" : "Suspended" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count = local.create_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.sse_algorithm
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = local.use_kms
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count = local.create_cloudtrail ? 1 : 0

  bucket                  = aws_s3_bucket.cloudtrail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  count = local.create_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    id     = "archive-and-expire"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration { days = 2557 } # 7 years (regulatory default)

    noncurrent_version_expiration { noncurrent_days = 90 }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count = local.create_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail[0].arn
        Condition = {
          StringEquals = { "aws:SourceOrgID" = var.organization_id }
        }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail[0].arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"    = "bucket-owner-full-control"
            "aws:SourceOrgID" = var.organization_id
          }
        }
      },
      {
        Sid       = "DenyNonTLSRequests"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.cloudtrail[0].arn, "${aws_s3_bucket.cloudtrail[0].arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "DenyDeleteObject"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:DeleteObject", "s3:DeleteObjectVersion"]
        Resource  = "${aws_s3_bucket.cloudtrail[0].arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.cloudtrail]
}

# ---- Config S3 Bucket --------------------------------------
resource "aws_s3_bucket" "config" {
  count = local.create_config ? 1 : 0

  bucket        = "${var.organization_name}-${var.environment}-config-logs"
  force_destroy = false
  tags          = { Name = "${var.organization_name}-${var.environment}-config-logs", Purpose = "config-archive" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  count = local.create_config ? 1 : 0

  bucket                  = aws_s3_bucket.config[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "config" {
  count = local.create_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  count = local.create_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.sse_algorithm
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = local.use_kms
  }
}

resource "aws_s3_bucket_policy" "config" {
  count = local.create_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowConfigService"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:ListBucket", "s3:PutObject"]
        Resource  = [aws_s3_bucket.config[0].arn, "${aws_s3_bucket.config[0].arn}/*"]
        Condition = {
          StringEquals = { "aws:SourceOrgID" = var.organization_id }
        }
      },
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.config[0].arn, "${aws_s3_bucket.config[0].arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.config]
}

# ---- GuardDuty Findings Bucket ------------------------------
resource "aws_s3_bucket" "guardduty" {
  count = local.create_guardduty ? 1 : 0

  bucket        = "${var.organization_name}-${var.environment}-guardduty-findings"
  force_destroy = false
  tags          = { Name = "${var.organization_name}-${var.environment}-guardduty-findings" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "guardduty" {
  count = local.create_guardduty ? 1 : 0

  bucket                  = aws_s3_bucket.guardduty[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "guardduty" {
  count = local.create_guardduty ? 1 : 0

  bucket = aws_s3_bucket.guardduty[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.sse_algorithm
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = local.use_kms
  }
}

# ---- Access Logging Bucket (meta-logging) -------------------
resource "aws_s3_bucket" "access_logs" {
  count = local.create_access_logs ? 1 : 0

  bucket        = "${var.organization_name}-${var.environment}-s3-access-logs"
  force_destroy = false
  tags          = { Name = "${var.organization_name}-${var.environment}-s3-access-logs" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  count = local.create_access_logs ? 1 : 0

  bucket                  = aws_s3_bucket.access_logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
