# ============================================================
# modules/vpc-flow-logs
# ============================================================
# Owned by the Landing Zone: this module is the single source of VPC Flow
# Logs for a Landing-Zone-managed VPC. It never creates a VPC — vpc_id is
# always passed in from modules/networking in THIS repo — and it never
# creates a new S3 bucket; S3 delivery (when enabled) writes to the
# existing central access-logs bucket under a dedicated prefix.
#
# Other repositories must NOT enable their own VPC Flow Logs module against
# a Landing-Zone-provided VPC. They consume this module's outputs
# (log_group_name / log_group_arn / bucket_prefix) from the Landing Zone's
# root outputs / remote state instead. Creating a second flow log on the
# same VPC/traffic-type is also simply rejected by the EC2 API as a
# duplicate, so there is a hard backstop, not just a convention.
# ============================================================

locals {
  name    = "${var.organization_name}-${var.environment}-${var.region_name}"
  want_cw = contains(["cloudwatch", "both"], var.destination)
  want_s3 = contains(["s3", "both"], var.destination)
  has_kms = var.kms_key_arn != null && var.kms_key_arn != ""
}

# ---- CloudWatch Logs destination -------------------------------------------
resource "aws_cloudwatch_log_group" "flow_logs" {
  count = local.want_cw ? 1 : 0

  name              = "/aws/vpc-flow-logs/${local.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.has_kms ? var.kms_key_arn : null

  tags = merge(var.tags, { Name = "${local.name}-vpc-flow-logs" })
}

resource "aws_iam_role" "flow_logs_to_cloudwatch" {
  count = local.want_cw ? 1 : 0

  name = "${local.name}-flowlogs-to-cwl"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowVpcFlowLogsAssume"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${local.name}-flowlogs-to-cwl" })
}

resource "aws_iam_role_policy" "flow_logs_to_cloudwatch" {
  count = local.want_cw ? 1 : 0

  name = "${local.name}-flowlogs-to-cwl"
  role = aws_iam_role.flow_logs_to_cloudwatch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "WriteFlowLogs"
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
    }]
  })
}

resource "aws_flow_log" "cloudwatch" {
  count = local.want_cw ? 1 : 0

  vpc_id                   = var.vpc_id
  traffic_type             = var.traffic_type
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn             = aws_iam_role.flow_logs_to_cloudwatch[0].arn
  max_aggregation_interval = 600

  tags = merge(var.tags, { Name = "${local.name}-vpc-flow-log-cwl" })
}

# ---- S3 destination (existing central access-logs bucket) ------------------
resource "aws_flow_log" "s3" {
  count = local.want_s3 ? 1 : 0

  vpc_id                   = var.vpc_id
  traffic_type             = var.traffic_type
  log_destination_type     = "s3"
  log_destination          = "${var.access_logs_bucket_arn}/${var.s3_key_prefix}"
  max_aggregation_interval = 600

  destination_options {
    file_format        = "parquet"
    per_hour_partition = true
  }

  tags = merge(var.tags, { Name = "${local.name}-vpc-flow-log-s3" })
}
