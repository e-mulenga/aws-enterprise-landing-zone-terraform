# ============================================================
# Module: security-hub — AWS Security Hub
# ============================================================

resource "aws_securityhub_account" "main" {
  enable_default_standards  = false
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true
}

# CIS AWS Foundations Benchmark v1.4.0
resource "aws_securityhub_standards_subscription" "cis_v1_4" {
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.main]
}

# AWS Foundational Security Best Practices
resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.main]
}

# NIST SP 800-53 Rev. 5
resource "aws_securityhub_standards_subscription" "nist" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/nist-800-53/v/5.0.0"
  depends_on    = [aws_securityhub_account.main]
}

# Organisation-wide configuration
resource "aws_securityhub_organization_configuration" "main" {
  auto_enable           = true
  auto_enable_standards = "NONE"

  organization_configuration {
    configuration_type = "CENTRAL"
  }

  depends_on = [aws_securityhub_account.main]
}

# EventBridge rule: CRITICAL and HIGH findings
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

resource "aws_sns_topic" "sechub_alerts" {
  name              = "${var.organization_name}-${var.environment}-sechub-alerts"
  kms_master_key_id = "alias/aws/sns"
  tags              = { Name = "${var.organization_name}-${var.environment}-sechub-alerts" }
}

resource "aws_cloudwatch_event_target" "sechub_alerts" {
  rule      = aws_cloudwatch_event_rule.sechub_critical.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.sechub_alerts.arn
}

data "aws_region" "current" {}
