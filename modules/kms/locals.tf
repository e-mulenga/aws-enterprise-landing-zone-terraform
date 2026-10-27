locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name

  # true  -> AWS managed keys (dev/test): NO customer managed keys are created.
  # false -> the five shared customer managed keys are created (prod).
  create_cmk = !var.use_aws_managed_keys

  # Account allowed to decrypt logs / appears in service conditions.
  management_account_id = var.management_account_id != "" ? var.management_account_id : local.account_id

  # Purpose of each shared key (portfolio governance view).
  shared_keys = {
    rds       = "Shared CMK for Amazon RDS / Aurora storage encryption"
    s3        = "Shared CMK for S3 buckets (also used for CloudTrail, Config and GuardDuty log delivery)"
    backup    = "Shared CMK for AWS Backup vaults"
    analytics = "Shared CMK for analytics workloads (Athena, Glue, OpenSearch, Redshift)"
    ai        = "Shared CMK for AI workloads (Bedrock logs, knowledge bases, model artefacts)"
  }

  # What a workload sees in dev/test: the AWS managed key alias to use.
  # AI has no AWS managed key: services fall back to AWS-owned keys (alias = null).
  aws_managed_alias = {
    rds       = "alias/aws/rds"
    s3        = "alias/aws/s3"
    backup    = "alias/aws/backup"
    analytics = "alias/aws/s3"
    ai        = null
  }

  # Extra key policy statements per key. Every key also gets the root statement.
  extra_statements = {
    rds       = []
    analytics = []

    backup = [
      {
        Sid       = "AllowAWSBackupService"
        Effect    = "Allow"
        Principal = { Service = "backup.amazonaws.com" }
        Action    = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey", "kms:CreateGrant"]
        Resource  = "*"
        Condition = { StringEquals = { "aws:SourceAccount" = local.account_id } }
      }
    ]

    s3 = concat(
      [
        {
          Sid       = "AllowCloudTrailEncrypt"
          Effect    = "Allow"
          Principal = { Service = "cloudtrail.amazonaws.com" }
          Action    = ["kms:GenerateDataKey*", "kms:DescribeKey"]
          Resource  = "*"
          Condition = {
            StringLike = {
              "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:${local.partition}:cloudtrail:*:${local.management_account_id}:trail/*"
            }
          }
        },
        {
          Sid       = "AllowConfigService"
          Effect    = "Allow"
          Principal = { Service = "config.amazonaws.com" }
          Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
          Resource  = "*"
          Condition = { StringEquals = { "aws:SourceAccount" = local.account_id } }
        },
        {
          Sid       = "AllowGuardDutyExport"
          Effect    = "Allow"
          Principal = { Service = "guardduty.amazonaws.com" }
          Action    = ["kms:GenerateDataKey"]
          Resource  = "*"
          Condition = { StringEquals = { "aws:SourceAccount" = local.account_id } }
        },
      ],
      var.logging_account_id == "" ? [] : [
        {
          Sid       = "AllowLoggingAccountDecrypt"
          Effect    = "Allow"
          Principal = { AWS = "arn:${local.partition}:iam::${var.logging_account_id}:root" }
          Action    = ["kms:Decrypt", "kms:DescribeKey"]
          Resource  = "*"
        }
      ]
    )

    ai = [
      {
        Sid       = "AllowBedrockService"
        Effect    = "Allow"
        Principal = { Service = "bedrock.amazonaws.com" }
        Action    = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
        Resource  = "*"
        Condition = { StringEquals = { "aws:SourceAccount" = local.account_id } }
      }
    ]
  }
}
