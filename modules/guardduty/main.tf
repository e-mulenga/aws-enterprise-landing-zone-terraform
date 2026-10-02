# ============================================================
# Module: guardduty — Amazon GuardDuty (Security Account)
# ============================================================

resource "aws_guardduty_detector" "main" {
  enable = var.enabled

  datasources {
    s3_logs { enable = true }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes { enable = true }
      }
    }
  }

  tags = { Name = "${var.organization_name}-${var.environment}-guardduty" }
}

resource "aws_guardduty_organization_configuration" "main" {
  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.main.id

  datasources {
    s3_logs { auto_enable = true }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes { auto_enable = true }
      }
    }
  }
}

# Publish findings to S3
resource "aws_guardduty_publishing_destination" "s3" {
  detector_id     = aws_guardduty_detector.main.id
  destination_arn = "arn:aws:s3:::${var.findings_bucket}"
  kms_key_arn     = var.kms_key_arn

  depends_on = [aws_guardduty_detector.main]
}

# EventBridge rule: high-severity findings → SNS
resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "${var.organization_name}-${var.environment}-guardduty-high"
  description = "Capture GuardDuty HIGH severity findings."

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_high_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_high.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.guardduty_alerts.arn
}

resource "aws_sns_topic" "guardduty_alerts" {
  name              = "${var.organization_name}-${var.environment}-guardduty-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = { Name = "${var.organization_name}-${var.environment}-guardduty-alerts" }
}
