# ============================================================
# Module: monitoring — CloudWatch, Budgets, Alarms
# ============================================================

# ---- SNS Alert Topic ----------------------------------------
resource "aws_sns_topic" "alerts" {
  name              = "${var.organization_name}-${var.environment}-platform-alerts"
  kms_master_key_id = "alias/aws/sns"
  tags              = { Name = "${var.organization_name}-${var.environment}-platform-alerts" }
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

resource "aws_cloudwatch_log_metric_filter" "alarms" {
  for_each = local.cloudtrail_alarms

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
  for_each = local.cloudtrail_alarms

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

# ---- CloudWatch Dashboard ------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.organization_name}-${var.environment}-landing-zone"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text"
        x    = 0
        y    = 0
        width = 24
        height = 2
        properties = {
          markdown = "# AWS Enterprise Landing Zone — ${upper(var.environment)} Security Dashboard\n> Centralised security posture for **${var.organization_name}**"
        }
      },
      {
        type = "metric"
        x    = 0
        y    = 2
        width = 8
        height = 6
        properties = {
          title  = "Unauthorised API Calls"
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [["LandingZone/SecurityEvents", "${var.organization_name}-${var.environment}-unauthorized-api-calls"]]
        }
      },
      {
        type = "metric"
        x    = 8
        y    = 2
        width = 8
        height = 6
        properties = {
          title  = "Root Account Logins"
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [["LandingZone/SecurityEvents", "${var.organization_name}-${var.environment}-root-login"]]
        }
      },
      {
        type = "metric"
        x    = 16
        y    = 2
        width = 8
        height = 6
        properties = {
          title  = "IAM Policy Changes"
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [["LandingZone/SecurityEvents", "${var.organization_name}-${var.environment}-iam-policy-changes"]]
        }
      },
      {
        type = "metric"
        x    = 0
        y    = 8
        width = 12
        height = 6
        properties = {
          title  = "Security Group Changes"
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [["LandingZone/SecurityEvents", "${var.organization_name}-${var.environment}-security-group-changes"]]
        }
      },
      {
        type = "metric"
        x    = 12
        y    = 8
        width = 12
        height = 6
        properties = {
          title  = "Console Logins Without MFA"
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [["LandingZone/SecurityEvents", "${var.organization_name}-${var.environment}-console-signin-without-mfa"]]
        }
      }
    ]
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
