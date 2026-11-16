# ============================================================
# Module: scp - Service Control Policies
#
# AWS allows at most 5 SCPs per root/OU/account INCLUDING the default FullAWSAccess policy. The previous
# layout attached 7 policies to the root, which fails at apply time. The same controls are consolidated
# into two policies (each well under the 5,120 character limit), leaving room for future OU-level SCPs.
# ============================================================

locals {
  pab_flags = ["BlockPublicAcls", "BlockPublicPolicy", "IgnorePublicAcls", "RestrictPublicBuckets"]
}

# ---- 1. Baseline guardrails ---------------------------------
resource "aws_organizations_policy" "baseline_guardrails" {
  name        = "BaselineGuardrails"
  description = "No public S3, no root user, protect CloudTrail and security services, IMDSv2, TLS only."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "DenyPublicS3Acl"
          Effect   = "Deny"
          Action   = ["s3:PutBucketAcl", "s3:PutObjectAcl"]
          Resource = "*"
          Condition = {
            StringEquals = { "s3:x-amz-acl" = ["public-read", "public-read-write", "authenticated-read"] }
          }
        }
      ],
      # One statement per flag: a single statement would only deny when ALL four flags are false.
      [
        for flag in local.pab_flags : {
          Sid      = "DenyDisable${flag}"
          Effect   = "Deny"
          Action   = ["s3:PutBucketPublicAccessBlock", "s3:PutAccountPublicAccessBlock"]
          Resource = "*"
          Condition = {
            StringEquals = { "s3:PublicAccessBlockConfiguration/${flag}" = "false" }
          }
        }
      ],
      [
        {
          Sid       = "DenyRootUser"
          Effect    = "Deny"
          Action    = "*"
          Resource  = "*"
          Condition = { StringLike = { "aws:PrincipalArn" = ["arn:aws:iam::*:root"] } }
        },
        {
          Sid    = "DenyCloudTrailDisablement"
          Effect = "Deny"
          Action = [
            "cloudtrail:DeleteTrail",
            "cloudtrail:StopLogging",
            "cloudtrail:UpdateTrail",
            "cloudtrail:PutEventSelectors",
          ]
          Resource = "*"
        },
        {
          Sid    = "DenyDisableSecurityServices"
          Effect = "Deny"
          Action = [
            "guardduty:DeleteDetector",
            "guardduty:DisassociateFromMasterAccount",
            "guardduty:DisassociateMembers",
            "guardduty:StopMonitoringMembers",
            "securityhub:DisableSecurityHub",
            "securityhub:DeleteHub",
            "config:DeleteConfigurationRecorder",
            "config:DeleteDeliveryChannel",
            "config:StopConfigurationRecorder",
            "access-analyzer:DeleteAnalyzer",
          ]
          Resource = "*"
        },
        {
          Sid       = "RequireIMDSv2"
          Effect    = "Deny"
          Action    = "ec2:RunInstances"
          Resource  = "arn:aws:ec2:*:*:instance/*"
          Condition = { StringNotEquals = { "ec2:MetadataHttpTokens" = "required" } }
        },
        {
          Sid       = "DenyNonTLS"
          Effect    = "Deny"
          Action    = ["s3:*", "sqs:*", "sns:*"]
          Resource  = "*"
          Condition = { Bool = { "aws:SecureTransport" = "false" } }
        },
      ]
    )
  })
}

# ---- 2. Region restriction ----------------------------------
resource "aws_organizations_policy" "region_restriction" {
  name        = "RegionRestriction"
  description = "Restricts activity to the approved regions. Global services are exempt."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyNonApprovedRegions"
      Effect = "Deny"
      NotAction = [
        "a4b:*", "acm:*", "aws-marketplace-management:*", "aws-marketplace:*",
        "budgets:*", "ce:*", "chime:*", "cloudfront:*", "config:*",
        "cur:*", "directconnect:*", "ec2:Describe*", "fms:*",
        "globalaccelerator:*", "health:*", "iam:*", "importexport:*",
        "kms:*", "mobileanalytics:*", "organizations:*", "pricing:*",
        "route53:*", "route53domains:*", "s3:GetAccountPublic*",
        "s3:ListAllMyBuckets", "s3:PutAccountPublic*", "shield:*",
        "sts:*", "support:*", "trustedadvisor:*", "waf-regional:*",
        "waf:*", "wafv2:*", "wellarchitected:*",
      ]
      Resource  = "*"
      Condition = { StringNotEquals = { "aws:RequestedRegion" = var.allowed_regions } }
    }]
  })
}

resource "aws_organizations_policy_attachment" "baseline_guardrails" {
  policy_id = aws_organizations_policy.baseline_guardrails.id
  target_id = var.organization_root_id
}

resource "aws_organizations_policy_attachment" "region_restriction" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = var.organization_root_id
}

# ---- 3. Per-OU policies (optional) --------------------------
# Each entry becomes one SCP attached to the OUs listed in target_ou_ids. The root already carries two policies plus
# FullAWSAccess, so a target may take at most two more (limit: 5 per target).
resource "aws_organizations_policy" "ou_policy" {
  for_each = var.ou_policies

  name        = each.key
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version   = "2012-10-17"
    Statement = jsondecode(each.value.statements_json)
  })
}

locals {
  # Flatten the map of policies → OU IDs into individual attachment pairs.
  ou_policy_attachments = merge([
    for policy_name, p in var.ou_policies : {
      for ou_id in p.target_ou_ids :
      "${policy_name}__${ou_id}" => {
        policy_name = policy_name
        ou_id       = ou_id
      }
    }
  ]...)
}

resource "aws_organizations_policy_attachment" "ou_policy" {
  for_each = local.ou_policy_attachments

  policy_id = aws_organizations_policy.ou_policy[each.value.policy_name].id
  target_id = each.value.ou_id
}
