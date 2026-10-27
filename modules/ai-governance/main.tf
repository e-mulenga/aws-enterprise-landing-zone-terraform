# ============================================================
# Module: ai-governance - Responsible AI foundation for Amazon Bedrock
# ============================================================
# What is created (and what it costs):
#   * AI audit bucket          - S3 storage only; lifecycle expires old logs.
#   * Invocation logging       - writes prompts/responses metadata to the bucket;
#                                no charge until a model is actually invoked.
#   * Baseline guardrail       - no standing charge; billed only per text unit
#                                when applications call it.
#   * Approved-models IAM policy - free; attach it to roles that call Bedrock.
# Nothing here invokes a model, so an idle account pays only S3 storage.
#
# The shared AI encryption key (shared-ai-key) is created by the kms module in
# prod and passed in as kms_key_arn. Dev/test pass null and use SSE-S3.
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "ai" {
  provider = aws.ai
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  ai_region  = data.aws_region.ai.name

  bucket_name = "${var.organization_name}-${var.environment}-ai-audit-${local.account_id}"
  log_prefix  = "bedrock-invocations"
  use_kms     = var.kms_key_arn != null
  tags        = { Purpose = "ai-audit", Name = local.bucket_name }

  # Inference profiles (eu.*, us.*) need BOTH the profile and the model ARN.
  model_resources = concat(
    var.approved_model_arns,
    ["arn:${local.partition}:bedrock:*:${local.account_id}:inference-profile/*", "arn:${local.partition}:bedrock:*::inference-profile/*"]
  )
}

# ---- AI audit bucket --------------------------------------------
resource "aws_s3_bucket" "ai_audit" {
  provider = aws.ai

  bucket        = local.bucket_name
  force_destroy = false
  tags          = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "ai_audit" {
  provider = aws.ai

  bucket                  = aws_s3_bucket.ai_audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "ai_audit" {
  provider = aws.ai

  bucket = aws_s3_bucket.ai_audit.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ai_audit" {
  provider = aws.ai

  bucket = aws_s3_bucket.ai_audit.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = local.use_kms
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ai_audit" {
  provider = aws.ai

  bucket = aws_s3_bucket.ai_audit.id

  rule {
    id     = "expire-ai-audit-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.audit_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "ai_audit_bucket" {
  statement {
    sid       = "AllowBedrockInvocationLogs"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.ai_audit.arn}/${local.log_prefix}/AWSLogs/${local.account_id}/BedrockModelInvocationLogs/*"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:bedrock:${local.ai_region}:${local.account_id}:*"]
    }
  }

  statement {
    sid     = "DenyNonTLS"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.ai_audit.arn,
      "${aws_s3_bucket.ai_audit.arn}/*",
    ]

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

resource "aws_s3_bucket_policy" "ai_audit" {
  provider = aws.ai

  bucket = aws_s3_bucket.ai_audit.id
  policy = data.aws_iam_policy_document.ai_audit_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.ai_audit]
}

# ---- Invocation logging (account + Region singleton) -------------
# Only one logging configuration exists per Region. If one is already set,
# keep enable_invocation_logging = false.
resource "aws_bedrock_model_invocation_logging_configuration" "this" {
  provider = aws.ai
  count    = var.enable_invocation_logging ? 1 : 0

  logging_config {
    embedding_data_delivery_enabled = true
    image_data_delivery_enabled     = false
    text_data_delivery_enabled      = true

    s3_config {
      bucket_name = aws_s3_bucket.ai_audit.id
      key_prefix  = local.log_prefix
    }
  }

  depends_on = [aws_s3_bucket_policy.ai_audit]
}

# ---- Baseline guardrail ----------------------------------------
resource "aws_bedrock_guardrail" "baseline" {
  provider = aws.ai
  count    = var.enable_guardrail ? 1 : 0

  name                      = "${var.organization_name}-${var.environment}-baseline"
  description               = "Baseline responsible-AI guardrail: harmful content, prompt attacks and secrets/PII."
  blocked_input_messaging   = "This request was blocked by the organisation AI policy."
  blocked_outputs_messaging = "This response was blocked by the organisation AI policy."
  kms_key_arn               = var.kms_key_arn

  content_policy_config {
    dynamic "filters_config" {
      for_each = ["HATE", "INSULTS", "SEXUAL", "VIOLENCE", "MISCONDUCT"]
      content {
        type            = filters_config.value
        input_strength  = "HIGH"
        output_strength = "HIGH"
      }
    }

    # Prompt-attack filtering only applies to inputs.
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  }

  sensitive_information_policy_config {
    dynamic "pii_entities_config" {
      for_each = {
        AWS_ACCESS_KEY           = "BLOCK"
        AWS_SECRET_KEY           = "BLOCK"
        PASSWORD                 = "BLOCK"
        CREDIT_DEBIT_CARD_NUMBER = "BLOCK"
        EMAIL                    = "ANONYMIZE"
        PHONE                    = "ANONYMIZE"
      }
      content {
        type   = pii_entities_config.key
        action = pii_entities_config.value
      }
    }
  }

  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }

  tags = { Name = "${var.organization_name}-${var.environment}-baseline-guardrail" }
}

resource "aws_bedrock_guardrail_version" "baseline" {
  provider = aws.ai
  count    = var.enable_guardrail ? 1 : 0

  guardrail_arn = aws_bedrock_guardrail.baseline[0].guardrail_arn
  description   = "Managed by Terraform"
  skip_destroy  = true
}

# ---- Approved models policy ------------------------------------
# Attach to any role that is allowed to call Bedrock. Models outside the
# approved list are denied even if another policy would allow them.
data "aws_iam_policy_document" "approved_models" {
  statement {
    sid    = "AllowApprovedModels"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:Converse",
      "bedrock:ConverseStream",
    ]
    resources = local.model_resources
  }

  statement {
    sid    = "DenyUnapprovedModels"
    effect = "Deny"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:Converse",
      "bedrock:ConverseStream",
    ]
    not_resources = local.model_resources
  }
}

resource "aws_iam_policy" "approved_models" {
  name        = "${var.organization_name}-${var.environment}-bedrock-approved-models"
  description = "Allows only the approved Amazon Bedrock models (AI governance baseline)."
  policy      = data.aws_iam_policy_document.approved_models.json

  tags = { Purpose = "ai-governance" }
}
