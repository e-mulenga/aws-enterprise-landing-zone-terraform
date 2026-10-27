# ============================================================
# Module: guardduty - Amazon GuardDuty
# ============================================================
# * create_detector = true  : this module owns the detector for the region.
# * create_detector = false : a detector ALREADY exists (console / other repo);
#                             it is looked up and its ID is re-exported, never
#                             recreated or changed.
#
# Cost posture: the 30-day free trial covers the first months. Afterwards the
# base service bills on CloudTrail events and VPC flow / DNS logs analysed,
# which is small for an idle account. The optional protection plans (S3, EKS,
# malware) bill per use and are OFF by default for dev.
# ============================================================

locals {
  tags = { Name = "${var.organization_name}-${var.environment}-guardduty" }
}

data "aws_caller_identity" "current" {}

resource "aws_guardduty_detector" "main" {
  count = var.create_detector ? 1 : 0

  enable                       = var.enabled
  finding_publishing_frequency = var.finding_publishing_frequency

  tags = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_guardduty_detector" "existing" {
  count = var.create_detector ? 0 : 1
}

locals {
  detector_id = one(concat(data.aws_guardduty_detector.existing[*].id, aws_guardduty_detector.main[*].id))

  features = {
    S3_DATA_EVENTS         = var.s3_protection
    EKS_AUDIT_LOGS         = var.eks_protection
    EBS_MALWARE_PROTECTION = var.malware_protection
  }
}

resource "aws_guardduty_detector_feature" "this" {
  for_each = var.create_detector ? local.features : {}

  detector_id = local.detector_id
  name        = each.key
  status      = each.value ? "ENABLED" : "DISABLED"
}

# Organisation-aware: auto-enable GuardDuty for every member account.
# Needs the management / delegated-admin account. Off for a single-account dev.
resource "aws_guardduty_organization_configuration" "main" {
  count = var.create_detector && var.organization_aware ? 1 : 0

  auto_enable_organization_members = "ALL"
  detector_id                      = local.detector_id
}

# Export findings to S3. GuardDuty only supports export with a customer
# managed key, so this is skipped when AWS managed keys are used (dev).
resource "aws_guardduty_publishing_destination" "s3" {
  count = var.create_detector && var.findings_bucket != "" && var.kms_key_arn != null ? 1 : 0

  detector_id     = local.detector_id
  destination_arn = "arn:aws:s3:::${var.findings_bucket}"
  kms_key_arn     = var.kms_key_arn
}

# ---- High-severity alerting ------------------------------------
resource "aws_sns_topic" "guardduty_alerts" {
  name = "${var.organization_name}-${var.environment}-guardduty-alerts"

  # EventBridge cannot publish to a topic encrypted with the AWS managed key
  # aws/sns. Leave null in dev; pass a CMK that trusts events.amazonaws.com in prod.
  kms_master_key_id = var.sns_kms_key_id

  tags = local.tags
}

data "aws_iam_policy_document" "alerts" {
  statement {
    sid       = "AllowEventBridgePublish"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.guardduty_alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.guardduty_alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.guardduty_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

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
