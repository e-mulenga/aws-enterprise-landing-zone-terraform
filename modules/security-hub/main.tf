# ============================================================
# Module: security-hub - AWS Security Hub (central dashboard)
# ============================================================
# Cost posture: Security Hub has a 30-day free trial per account and Region.
# Afterwards pricing is per protected resource, so only standards you need are
# subscribed. Dev subscribes to AWS Foundational Security Best Practices only.
# ============================================================

data "aws_region" "current" {}

locals {
  standard_arns = {
    fsbp = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
    cis  = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0"
    nist = "arn:aws:securityhub:${data.aws_region.current.name}::standards/nist-800-53/v/5.0.0"
  }
}

resource "aws_securityhub_account" "main" {
  enable_default_standards  = false
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_securityhub_standards_subscription" "this" {
  for_each = toset(var.standards)

  standards_arn = local.standard_arns[each.key]
  depends_on    = [aws_securityhub_account.main]
}

# Organisation-wide configuration (management / delegated admin only).
resource "aws_securityhub_organization_configuration" "main" {
  count = var.organization_aware ? 1 : 0

  auto_enable           = true
  auto_enable_standards = "NONE"

  organization_configuration {
    configuration_type = "CENTRAL"
  }

  depends_on = [aws_securityhub_account.main]
}

# ---- CRITICAL / HIGH finding alerting --------------------------
resource "aws_sns_topic" "sechub_alerts" {
  name = "${var.organization_name}-${var.environment}-sechub-alerts"

  # EventBridge cannot publish to a topic encrypted with aws/sns.
  kms_master_key_id = var.sns_kms_key_id

  tags = { Name = "${var.organization_name}-${var.environment}-sechub-alerts" }
}

data "aws_iam_policy_document" "alerts" {
  statement {
    sid       = "AllowEventBridgePublish"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.sechub_alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.sechub_alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}

resource "aws_cloudwatch_event_rule" "sechub_critical" {
  name        = "${var.organization_name}-${var.environment}-sechub-critical"
  description = "Capture Security Hub CRITICAL/HIGH findings."

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity    = { Label = ["CRITICAL", "HIGH"] }
        Workflow    = { Status = ["NEW"] }
        RecordState = ["ACTIVE"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "sechub_alerts" {
  rule      = aws_cloudwatch_event_rule.sechub_critical.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.sechub_alerts.arn
}
