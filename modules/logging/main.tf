# ============================================================
# Module: logging — Centralised Log Archive (Logging Account)
# ============================================================

data "aws_caller_identity" "current" {}

# ---- CloudTrail S3 Bucket -----------------------------------
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = var.cloudtrail_bucket
  force_destroy = false

  tags = { Name = var.cloudtrail_bucket, Purpose = "cloudtrail-archive" }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration { status = var.s3_versioning_enabled ? "Enabled" : "Suspended" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "archive-and-expire"
    status = "Enabled"

    filter {
      prefix = ""
    }

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

resource "aws_s3_bucket_logging" "cloudtrail" {
  bucket        = aws_s3_bucket.cloudtrail.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "cloudtrail-logs/"
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail.arn
        Condition = {
          StringEquals = { "aws:SourceOrgID" = var.organization_id }
        }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/*"
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
        Resource  = ["${aws_s3_bucket.cloudtrail.arn}", "${aws_s3_bucket.cloudtrail.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "DenyDeleteObject"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:DeleteObject", "s3:DeleteObjectVersion"]
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/*"
      }
    ]
  })
}

# ---- Config S3 Bucket --------------------------------------
resource "aws_s3_bucket" "config" {
  bucket        = "${var.organization_name}-${var.environment}-config-logs"
  force_destroy = false
  tags          = { Name = "${var.organization_name}-${var.environment}-config-logs", Purpose = "config-archive" }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "config" {
  bucket        = aws_s3_bucket.config.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "config-logs/"
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowConfigService"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:ListBucket", "s3:PutObject"]
        Resource  = [aws_s3_bucket.config.arn, "${aws_s3_bucket.config.arn}/*"]
        Condition = {
          StringEquals = { "aws:SourceOrgID" = var.organization_id }
        }
      },
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = ["${aws_s3_bucket.config.arn}", "${aws_s3_bucket.config.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
}

# ---- GuardDuty Findings Bucket ------------------------------
resource "aws_s3_bucket" "guardduty" {
  bucket        = "${var.organization_name}-${var.environment}-guardduty-findings"
  force_destroy = false
  tags          = { Name = "${var.organization_name}-${var.environment}-guardduty-findings" }
}

resource "aws_s3_bucket_public_access_block" "guardduty" {
  bucket                  = aws_s3_bucket.guardduty.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "guardduty" {
  bucket = aws_s3_bucket.guardduty.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "guardduty" {
  bucket = aws_s3_bucket.guardduty.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "guardduty" {
  bucket        = aws_s3_bucket.guardduty.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "guardduty-logs/"
}

# ---- Access Logging Bucket (meta-logging) -------------------
resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.organization_name}-${var.environment}-s3-access-logs"
  force_destroy = false
  tags          = { Name = "${var.organization_name}-${var.environment}-s3-access-logs" }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_logging" "access_logs" {
  bucket        = aws_s3_bucket.access_logs.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "access-logs/"
}