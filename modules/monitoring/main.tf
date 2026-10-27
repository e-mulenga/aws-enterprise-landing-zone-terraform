# ============================================================
# Module: monitoring — CloudWatch, Budgets, Alarms
# ============================================================

# ---- SNS Alert Topic ----------------------------------------
# CloudWatch alarms and EventBridge cannot publish to a topic encrypted with the
# AWS managed key aws/sns, so the topic is unencrypted by default. Prod can pass
# a customer managed key that trusts cloudwatch.amazonaws.com and events.amazonaws.com.
resource "aws_sns_topic" "alerts" {
  name              = "${var.organization_name}-${var.environment}-platform-alerts"
  kms_master_key_id = var.sns_kms_key_id
  tags              = { Name = "${var.organization_name}-${var.environment}-platform-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  count = var.budget_alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.budget_alert_email
}

# ---- CloudTrail Metric Filters & Alarms ---------------------
locals {
  cloudtrail_alarms = {
    "unauthorized-api-calls" = {
      pattern     = "{($.errorCode = \"*UnauthorizedAccess*\") || ($.errorCode = \"AccessDenied\")}"
      description = "Unauthorised API calls detected."
    }
    "root-login" = {
      pattern     = "{$.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\"}"
      description = "Root account login detected."
    }
    "console-signin-without-mfa" = {
      pattern     = "{($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\")}"
      description = "AWS Console login without MFA."
    }
    "iam-policy-changes" = {
      pattern     = "{($.eventName=DeleteGroupPolicy) || ($.eventName=DeleteRolePolicy) || ($.eventName=DeleteUserPolicy) || ($.eventName=PutGroupPolicy) || ($.eventName=PutRolePolicy) || ($.eventName=PutUserPolicy) || ($.eventName=CreatePolicy) || ($.eventName=DeletePolicy) || ($.eventName=CreatePolicyVersion) || ($.eventName=DeletePolicyVersion) || ($.eventName=SetDefaultPolicyVersion) || ($.eventName=AttachRolePolicy) || ($.eventName=DetachRolePolicy) || ($.eventName=AttachUserPolicy) || ($.eventName=DetachUserPolicy) || ($.eventName=AttachGroupPolicy) || ($.eventName=DetachGroupPolicy)}"
      description = "IAM policy change detected."
    }
    "cloudtrail-config-changes" = {
      pattern     = "{($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging)}"
      description = "CloudTrail configuration change detected."
    }
    "s3-bucket-policy-changes" = {
      pattern     = "{($.eventSource = s3.amazonaws.com) && (($.eventName = PutBucketAcl) || ($.eventName = PutBucketPolicy) || ($.eventName = PutBucketCors) || ($.eventName = PutBucketLifecycle) || ($.eventName = PutBucketReplication) || ($.eventName = DeleteBucketPolicy) || ($.eventName = DeleteBucketCors) || ($.eventName = DeleteBucketLifecycle) || ($.eventName = DeleteBucketReplication))}"
      description = "S3 bucket policy change detected."
    }
    "network-acl-changes" = {
      pattern     = "{($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation)}"
      description = "Network ACL change detected."
    }
    "security-group-changes" = {
      pattern     = "{($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup)}"
      description = "Security group change detected."
    }
    "kms-key-deletion" = {
      pattern     = "{($.eventSource = kms.amazonaws.com) && (($.eventName = DisableKey) || ($.eventName = ScheduleKeyDeletion))}"
      description = "KMS key scheduled for deletion or disabled."
    }
  }
}

# Metric filters and alarms need a CloudTrail log group. If the trail was created
# in the console without CloudWatch Logs, leave cloudtrail_log_group empty.
# Each alarm costs about USD 0.10 per month.
locals {
  active_alarms = var.enable_security_alarms && var.cloudtrail_log_group != "" ? local.cloudtrail_alarms : {}
}

resource "aws_cloudwatch_log_metric_filter" "alarms" {
  for_each = local.active_alarms

  name           = "${var.organization_name}-${var.environment}-${each.key}"
  pattern        = each.value.pattern
  log_group_name = var.cloudtrail_log_group

  metric_transformation {
    name      = "${var.organization_name}-${var.environment}-${each.key}"
    namespace = "LandingZone/SecurityEvents"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "alarms" {
  for_each = local.active_alarms

  alarm_name          = "${var.organization_name}-${var.environment}-${each.key}"
  alarm_description   = each.value.description
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "${var.organization_name}-${var.environment}-${each.key}"
  namespace           = "LandingZone/SecurityEvents"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  tags = { Severity = "HIGH" }
}

# ---- Findings feed (GuardDuty, Security Hub, Config) ---------
# EventBridge rules for AWS service events are free. Events land in a small
# log group that the dashboard queries with Logs Insights.
resource "aws_cloudwatch_log_group" "findings" {
  count = var.enable_findings_feed ? 1 : 0

  name              = "/aws/events/${var.organization_name}-${var.environment}-security-findings"
  retention_in_days = var.findings_retention_days

  tags = { Name = "${var.organization_name}-${var.environment}-security-findings" }
}

data "aws_iam_policy_document" "findings_feed" {
  count = var.enable_findings_feed ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]

    resources = ["${aws_cloudwatch_log_group.findings[0].arn}:*"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "delivery.logs.amazonaws.com"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "findings_feed" {
  count = var.enable_findings_feed ? 1 : 0

  policy_name     = "${var.organization_name}-${var.environment}-findings-feed"
  policy_document = data.aws_iam_policy_document.findings_feed[0].json
}

locals {
  findings_sources = {
    guardduty   = { source = "aws.guardduty", detail_type = "GuardDuty Finding" }
    securityhub = { source = "aws.securityhub", detail_type = "Security Hub Findings - Imported" }
    config      = { source = "aws.config", detail_type = "Config Rules Compliance Change" }
  }
}

resource "aws_cloudwatch_event_rule" "findings" {
  for_each = var.enable_findings_feed ? local.findings_sources : {}

  name        = "${var.organization_name}-${var.environment}-feed-${each.key}"
  description = "Copy ${each.key} events to the findings log group for the dashboard."

  event_pattern = jsonencode({
    source      = [each.value.source]
    detail-type = [each.value.detail_type]
  })
}

resource "aws_cloudwatch_event_target" "findings" {
  for_each = aws_cloudwatch_event_rule.findings

  rule      = each.value.name
  target_id = "ToLogs"
  arn       = aws_cloudwatch_log_group.findings[0].arn

  depends_on = [aws_cloudwatch_log_resource_policy.findings_feed]
}

# ---- CloudWatch Dashboard ------------------------------------
# The first three dashboards in an account are free (up to 50 metrics each).
locals {
  security_metric_widgets = var.cloudtrail_log_group == "" ? [] : [
    {
      type   = "metric"
      x      = 0
      y      = 2
      width  = 12
      height = 6
      properties = {
        region = var.aws_region
        title  = "Security events (CloudTrail metric filters)"
        period = 300
        stat   = "Sum"
        view   = "timeSeries"
        metrics = [
          for k in ["unauthorized-api-calls", "root-login", "iam-policy-changes", "security-group-changes", "console-signin-without-mfa"] :
          ["LandingZone/SecurityEvents", "${var.organization_name}-${var.environment}-${k}"]
        ]
      }
    }
  ]

  findings_widgets = var.enable_findings_feed ? [
    {
      type   = "log"
      x      = 12
      y      = 2
      width  = 12
      height = 6
      properties = {
        region = var.aws_region
        title  = "Security findings by source (last 7 days)"
        view   = "bar"
        query  = "SOURCE '${aws_cloudwatch_log_group.findings[0].name}' | stats count(*) as findings by source"
      }
    },
    {
      type   = "log"
      x      = 0
      y      = 8
      width  = 12
      height = 6
      properties = {
        region = var.aws_region
        title  = "Config compliance changes (latest)"
        view   = "table"
        query  = "SOURCE '${aws_cloudwatch_log_group.findings[0].name}' | filter source = 'aws.config' | fields @timestamp, detail.configRuleName, detail.newEvaluationResult.complianceType | sort @timestamp desc | limit 20"
      }
    }
  ] : []
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.organization_name}-${var.environment}-landing-zone"

  dashboard_body = jsonencode({
    widgets = concat(
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 2
          properties = {
            markdown = "# AWS Enterprise Landing Zone - ${upper(var.environment)}\nSecurity findings, backup status, Config compliance, GuardDuty and cost in one place."
          }
        }
      ],
      local.security_metric_widgets,
      local.findings_widgets,
      [
        {
          type   = "metric"
          x      = 12
          y      = 8
          width  = 6
          height = 6
          properties = {
            region  = var.aws_region
            title   = "Backup jobs (failed vs completed)"
            period  = 86400
            stat    = "Sum"
            view    = "timeSeries"
            metrics = [["AWS/Backup", "NumberOfBackupJobsFailed"], ["AWS/Backup", "NumberOfBackupJobsCompleted"]]
          }
        },
        {
          type   = "metric"
          x      = 18
          y      = 8
          width  = 6
          height = 6
          properties = {
            # Billing metrics exist only in us-east-1.
            region  = "us-east-1"
            title   = "Estimated month-to-date charges (USD)"
            period  = 21600
            stat    = "Maximum"
            view    = "timeSeries"
            metrics = [["AWS/Billing", "EstimatedCharges", "Currency", "USD"]]
          }
        }
      ]
    )
  })
}

# ---- AWS Budgets --------------------------------------------
resource "aws_budgets_budget" "monthly" {
  count = var.monthly_budget_usd > 0 ? 1 : 0

  name         = "${var.organization_name}-${var.environment}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_email != "" ? [var.budget_alert_email] : []
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_email != "" ? [var.budget_alert_email] : []
  }
}
