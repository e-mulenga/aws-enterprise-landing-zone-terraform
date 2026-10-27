# ============================================================
# Module: cloudtrail - Organisation CloudTrail Trail
# ============================================================

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.organization_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = { Name = "${var.organization_name}-${var.environment}-cloudtrail-lg" }
}

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "${var.organization_name}-${var.environment}-cloudtrail-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "cloudtrail-cloudwatch-delivery"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

resource "aws_cloudtrail" "org_trail" {
  name                          = "${var.organization_name}-${var.environment}-org-trail"
  s3_bucket_name                = var.s3_bucket_name
  kms_key_id                    = var.kms_key_arn
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = var.is_organization_trail
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    # Data events are billed per event (USD 0.10 per 100,000). Off by default;
    # turn on in prod, or scope to specific buckets for a demo.
    dynamic "data_resource" {
      for_each = var.data_events_enabled ? {
        "AWS::S3::Object"       = "arn:aws:s3:::"
        "AWS::Lambda::Function" = "arn:aws:lambda"
      } : {}

      content {
        type   = data_resource.key
        values = [data_resource.value]
      }
    }
  }

  # CloudTrail Insights is billed per event analysed. Off by default.
  dynamic "insight_selector" {
    for_each = var.insights_enabled ? ["ApiCallRateInsight", "ApiErrorRateInsight"] : []

    content {
      insight_type = insight_selector.value
    }
  }

  tags = {
    Name = "${var.organization_name}-${var.environment}-org-trail"
  }

  lifecycle {
    prevent_destroy = true
  }
}
