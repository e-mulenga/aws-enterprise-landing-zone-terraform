# ============================================================
# Module: config — AWS Config (Organisation-wide)
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "config" {
  name = "${var.organization_name}-${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_service" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  name = "config-s3-delivery"
  role = aws_iam_role.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "arn:aws:s3:::${var.s3_bucket_name}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
      Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
    }, {
      Effect   = "Allow"
      Action   = ["s3:GetBucketAcl"]
      Resource = "arn:aws:s3:::${var.s3_bucket_name}"
    }, {
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
      Resource = var.kms_key_arn
    }]
  })
}

resource "aws_config_configuration_recorder" "main" {
  name     = "${var.organization_name}-${var.environment}-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  recording_mode {
    recording_frequency = "CONTINUOUS"
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.organization_name}-${var.environment}-config-delivery"
  s3_bucket_name = var.s3_bucket_name

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = var.enabled
  depends_on = [aws_config_delivery_channel.main]
}

# ---- Managed Config Rules -----------------------------------
locals {
  managed_rules = {
    "s3-bucket-public-read-prohibited"             = {}
    "s3-bucket-public-write-prohibited"            = {}
    "s3-bucket-server-side-encryption-enabled"     = {}
    "s3-bucket-ssl-requests-only"                  = {}
    "s3-bucket-versioning-enabled"                 = {}
    "cloudtrail-enabled"                           = {}
    "cloudtrail-encryption-enabled"                = {}
    "cloudtrail-log-file-validation-enabled"       = {}
    "guardduty-enabled-centralized"                = {}
    "securityhub-enabled"                          = {}
    "iam-root-access-key-check"                    = {}
    "mfa-enabled-for-iam-console-access"           = {}
    "iam-user-mfa-enabled"                         = {}
    "iam-password-policy"                          = {}
    "ec2-imdsv2-check"                             = {}
    "restricted-ssh"                               = {}
    "vpc-flow-logs-enabled"                        = {}
    "kms-cmk-not-scheduled-for-deletion"           = {}
    "encrypted-volumes"                            = {}
    "rds-storage-encrypted"                        = {}
  }
}

resource "aws_config_config_rule" "managed" {
  for_each = local.managed_rules

  name = each.key

  source {
    owner             = "AWS"
    source_identifier = upper(replace(each.key, "-", "_"))
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}
