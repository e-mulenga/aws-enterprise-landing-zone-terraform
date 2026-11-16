# ============================================================
# Module: cost-reporting - Cost and Usage Report (CUR) to S3
# ============================================================
# Daily Parquet report with Athena-ready layout. The report is free; you pay for S3 storage (kept small by the lifecycle rule) and for
# Athena queries when you run them. The CUR API only exists in us-east-1, so this module uses the aws.us_east_1 provider.
# The bucket is encrypted with SSE-S3 because CUR delivery does not support a customer managed key on the destination bucket.
# Region check: billing services are global (us-east-1 endpoint), so the Ireland rule does not apply.
# ============================================================

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.organization_name}-${var.environment}-cur-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "cur" {
  provider = aws.us_east_1

  bucket        = local.bucket_name
  force_destroy = false

  tags = { Name = local.bucket_name, Purpose = "cost-and-usage-report" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "cur" {
  provider = aws.us_east_1

  bucket                  = aws_s3_bucket.cur.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cur" {
  provider = aws.us_east_1

  bucket = aws_s3_bucket.cur.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cur" {
  provider = aws.us_east_1

  bucket = aws_s3_bucket.cur.id

  rule {
    id     = "expire-old-reports"
    status = "Enabled"

    filter {}

    expiration { days = var.retention_days }
  }
}

data "aws_iam_policy_document" "cur" {
  statement {
    sid       = "AllowBillingReportsRead"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl", "s3:GetBucketPolicy"]
    resources = [aws_s3_bucket.cur.arn]

    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cur:us-east-1:${data.aws_caller_identity.current.account_id}:definition/*"]
    }
  }

  statement {
    sid       = "AllowBillingReportsWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cur.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cur:us-east-1:${data.aws_caller_identity.current.account_id}:definition/*"]
    }
  }

  statement {
    sid       = "DenyNonTLS"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.cur.arn, "${aws_s3_bucket.cur.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "cur" {
  provider = aws.us_east_1

  bucket = aws_s3_bucket.cur.id
  policy = data.aws_iam_policy_document.cur.json

  depends_on = [aws_s3_bucket_public_access_block.cur]
}

resource "aws_cur_report_definition" "daily" {
  provider = aws.us_east_1

  report_name                = "${var.organization_name}-${var.environment}-daily"
  time_unit                  = "DAILY"
  format                     = "Parquet"
  compression                = "Parquet"
  additional_schema_elements = ["RESOURCES"]
  additional_artifacts       = ["ATHENA"]
  s3_bucket                  = aws_s3_bucket.cur.id
  s3_prefix                  = "cur"
  s3_region                  = "us-east-1"
  report_versioning          = "OVERWRITE_REPORT"

  depends_on = [aws_s3_bucket_policy.cur]
}
