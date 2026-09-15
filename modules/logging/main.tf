# ============================================================
# Module: logging — Centralised Log Archive (Logging Account)
# ============================================================[cite: 1]

data "aws_caller_identity" "current" {}[cite: 1]

# ---- CloudTrail S3 Bucket -----------------------------------[cite: 1]
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = var.cloudtrail_bucket[cite: 1]
  force_destroy = false[cite: 1]

  tags = { Name = var.cloudtrail_bucket, Purpose = "cloudtrail-archive" }[cite: 1]
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id[cite: 1]
  versioning_configuration { status = var.s3_versioning_enabled ? "Enabled" : "Suspended" }[cite: 1]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id[cite: 1]
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"[cite: 1]
      kms_master_key_id = var.kms_key_arn[cite: 1]
    }
    bucket_key_enabled = true[cite: 1]
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id[cite: 1]
  block_public_acls       = true[cite: 1]
  block_public_policy     = true[cite: 1]
  ignore_public_acls      = true[cite: 1]
  restrict_public_buckets = true[cite: 1]
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id[cite: 1]

  rule {
    id     = "archive-and-expire"[cite: 1]
    status = "Enabled"[cite: 1]

    transition {
      days          = 90[cite: 1]
      storage_class = "STANDARD_IA"[cite: 1]
    }

    transition {
      days          = 365[cite: 1]
      storage_class = "GLACIER"[cite: 1]
    }

    expiration { days = 2557 } # 7 years (regulatory default)[cite: 1]

    noncurrent_version_expiration { noncurrent_days = 90 }[cite: 1]
  }
}

resource "aws_s3_bucket_logging" "cloudtrail" {
  bucket        = aws_s3_bucket.cloudtrail.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "cloudtrail-logs/"
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id[cite: 1]

  policy = jsonencode({
    Version = "2012-10-17"[cite: 1]
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"[cite: 1]
        Effect = "Allow"[cite: 1]
        Principal = { Service = "cloudtrail.amazonaws.com" }[cite: 1]
        Action   = "s3:GetBucketAcl"[cite: 1]
        Resource = aws_s3_bucket.cloudtrail.arn[cite: 1]
        Condition = {
          StringEquals = { "aws:SourceOrgID" = var.organization_id }[cite: 1]
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"[cite: 1]
        Effect = "Allow"[cite: 1]
        Principal = { Service = "cloudtrail.amazonaws.com" }[cite: 1]
        Action   = "s3:PutObject"[cite: 1]
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/*"[cite: 1]
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"[cite: 1]
            "aws:SourceOrgID" = var.organization_id[cite: 1]
          }
        }
      },
      {
        Sid    = "DenyNonTLSRequests"[cite: 1]
        Effect = "Deny"[cite: 1]
        Principal = "*"[cite: 1]
        Action    = "s3:*"[cite: 1]
        Resource  = ["${aws_s3_bucket.cloudtrail.arn}", "${aws_s3_bucket.cloudtrail.arn}/*"][cite: 1]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }[cite: 1]
      },
      {
        Sid    = "DenyDeleteObject"[cite: 1]
        Effect = "Deny"[cite: 1]
        Principal = "*"[cite: 1]
        Action    = ["s3:DeleteObject", "s3:DeleteObjectVersion"][cite: 1]
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/*"[cite: 1]
      }
    ]
  })
}

# ---- Config S3 Bucket --------------------------------------[cite: 1]
resource "aws_s3_bucket" "config" {
  bucket        = "${var.organization_name}-${var.environment}-config-logs"[cite: 1]
  force_destroy = false[cite: 1]
  tags          = { Name = "${var.organization_name}-${var.environment}-config-logs", Purpose = "config-archive" }[cite: 1]
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id[cite: 1]
  block_public_acls       = true[cite: 1]
  block_public_policy     = true[cite: 1]
  ignore_public_acls      = true[cite: 1]
  restrict_public_buckets = true[cite: 1]
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id[cite: 1]
  versioning_configuration { status = "Enabled" }[cite: 1]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id[cite: 1]
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"[cite: 1]
      kms_master_key_id = var.kms_key_arn[cite: 1]
    }
    bucket_key_enabled = true[cite: 1]
  }
}

resource "aws_s3_bucket_logging" "config" {
  bucket        = aws_s3_bucket.config.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "config-logs/"
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id[cite: 1]
  policy = jsonencode({
    Version = "2012-10-17"[cite: 1]
    Statement = [
      {
        Sid    = "AllowConfigService"[cite: 1]
        Effect = "Allow"[cite: 1]
        Principal = { Service = "config.amazonaws.com" }[cite: 1]
        Action   = ["s3:GetBucketAcl", "s3:ListBucket", "s3:PutObject"][cite: 1]
        Resource = [aws_s3_bucket.config.arn, "${aws_s3_bucket.config.arn}/*"][cite: 1]
        Condition = {
          StringEquals = { "aws:SourceOrgID" = var.organization_id }[cite: 1]
        }
      },
      {
        Sid    = "DenyNonTLS"[cite: 1]
        Effect = "Deny"[cite: 1]
        Principal = "*"[cite: 1]
        Action    = "s3:*"[cite: 1]
        Resource  = ["${aws_s3_bucket.config.arn}", "${aws_s3_bucket.config.arn}/*"][cite: 1]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }[cite: 1]
      }
    ]
  })
}

# ---- GuardDuty Findings Bucket ------------------------------[cite: 1]
resource "aws_s3_bucket" "guardduty" {
  bucket        = "${var.organization_name}-${var.environment}-guardduty-findings"[cite: 1]
  force_destroy = false[cite: 1]
  tags          = { Name = "${var.organization_name}-${var.environment}-guardduty-findings" }[cite: 1]
}

resource "aws_s3_bucket_public_access_block" "guardduty" {
  bucket                  = aws_s3_bucket.guardduty.id[cite: 1]
  block_public_acls       = true[cite: 1]
  block_public_policy     = true[cite: 1]
  ignore_public_acls      = true[cite: 1]
  restrict_public_buckets = true[cite: 1]
}

resource "aws_s3_bucket_versioning" "guardduty" {
  bucket = aws_s3_bucket.guardduty.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "guardduty" {
  bucket = aws_s3_bucket.guardduty.id[cite: 1]
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"[cite: 1]
      kms_master_key_id = var.kms_key_arn[cite: 1]
    }
    bucket_key_enabled = true[cite: 1]
  }
}

resource "aws_s3_bucket_logging" "guardduty" {
  bucket        = aws_s3_bucket.guardduty.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "guardduty-logs/"
}

# ---- Access Logging Bucket (meta-logging) -------------------[cite: 1]
resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.organization_name}-${var.environment}-s3-access-logs"[cite: 1]
  force_destroy = false[cite: 1]
  tags          = { Name = "${var.organization_name}-${var.environment}-s3-access-logs" }[cite: 1]
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id[cite: 1]
  block_public_acls       = true[cite: 1]
  block_public_policy     = true[cite: 1]
  ignore_public_acls      = true[cite: 1]
  restrict_public_buckets = true[cite: 1]
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