# ============================================================
# Module: scp — Service Control Policies
# ============================================================

# ---- Deny Public S3 ACLs ------------------------------------
resource "aws_organizations_policy" "deny_public_s3" {
  name        = "DenyPublicS3"
  description = "Prevents any account from making S3 buckets or objects public."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyS3PublicACL"
        Effect   = "Deny"
        Action   = ["s3:PutBucketAcl", "s3:PutObjectAcl", "s3:PutBucketPublicAccessBlock"]
        Resource = "*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = ["public-read", "public-read-write", "authenticated-read"] }
        }
      },
      {
        Sid    = "DenyDisableBlockPublicAccess"
        Effect = "Deny"
        Action = "s3:PutBucketPublicAccessBlock"
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:PublicAccessBlockConfiguration/BlockPublicAcls"       = "false"
            "s3:PublicAccessBlockConfiguration/BlockPublicPolicy"     = "false"
            "s3:PublicAccessBlockConfiguration/IgnorePublicAcls"     = "false"
            "s3:PublicAccessBlockConfiguration/RestrictPublicBuckets" = "false"
          }
        }
      }
    ]
  })
}

# ---- Deny Root Account Usage --------------------------------
resource "aws_organizations_policy" "deny_root_access" {
  name        = "DenyRootAccountUsage"
  description = "Prevents use of the root account user."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyRootUser"
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
      Condition = {
        StringLike = { "aws:PrincipalArn" = ["arn:aws:iam::*:root"] }
      }
    }]
  })
}

# ---- Deny Non-Approved Regions ------------------------------
resource "aws_organizations_policy" "deny_non_approved_regions" {
  name        = "DenyNonApprovedRegions"
  description = "Restricts AWS activity to approved regions only."
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
        "waf:*", "wafv2:*", "wellarchitected:*"
      ]
      Resource = "*"
      Condition = {
        StringNotEquals = { "aws:RequestedRegion" = var.allowed_regions }
      }
    }]
  })
}

# ---- Deny Disabling CloudTrail ------------------------------
resource "aws_organizations_policy" "deny_disable_cloudtrail" {
  name        = "DenyDisableCloudTrail"
  description = "Prevents disabling or deleting CloudTrail trails."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyCloudTrailDisablement"
      Effect = "Deny"
      Action = [
        "cloudtrail:DeleteTrail",
        "cloudtrail:StopLogging",
        "cloudtrail:UpdateTrail",
        "cloudtrail:PutEventSelectors"
      ]
      Resource = "*"
    }]
  })
}

# ---- Deny Disabling GuardDuty / Security Hub ----------------
resource "aws_organizations_policy" "deny_disable_security_services" {
  name        = "DenyDisableSecurityServices"
  description = "Prevents disabling GuardDuty, Security Hub, AWS Config, or Access Analyser."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyDisableSecurityServices"
      Effect = "Deny"
      Action = [
        "guardduty:DeleteDetector", "guardduty:DisassociateFromMasterAccount",
        "guardduty:DisassociateMembers",  "guardduty:StopMonitoringMembers",
        "securityhub:DisableSecurityHub", "securityhub:DeleteHub",
        "config:DeleteConfigurationRecorder", "config:DeleteDeliveryChannel",
        "config:StopConfigurationRecorder",
        "access-analyzer:DeleteAnalyzer"
      ]
      Resource = "*"
    }]
  })
}

# ---- Require IMDSv2 for EC2 ----------------------------------
resource "aws_organizations_policy" "require_imdsv2" {
  name        = "RequireIMDSv2"
  description = "Enforces use of IMDSv2 on all EC2 instances."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "RequireIMDSv2"
      Effect = "Deny"
      Action = "ec2:RunInstances"
      Resource = "arn:aws:ec2:*:*:instance/*"
      Condition = {
        StringNotEquals = { "ec2:MetadataHttpTokens" = "required" }
      }
    }]
  })
}

# ---- Require Encryption in Transit --------------------------
resource "aws_organizations_policy" "deny_unencrypted_transit" {
  name        = "DenyUnencryptedTransit"
  description = "Denies API calls that do not use TLS."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyNonTLSAccess"
      Effect = "Deny"
      Action = ["s3:*", "sqs:*", "sns:*"]
      Resource = "*"
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}

# ---- Attach SCPs to Root ------------------------------------
resource "aws_organizations_policy_attachment" "deny_public_s3_root" {
  policy_id = aws_organizations_policy.deny_public_s3.id
  target_id = var.organization_root_id
}

resource "aws_organizations_policy_attachment" "deny_root_access" {
  policy_id = aws_organizations_policy.deny_root_access.id
  target_id = var.organization_root_id
}

resource "aws_organizations_policy_attachment" "deny_non_approved_regions" {
  policy_id = aws_organizations_policy.deny_non_approved_regions.id
  target_id = var.organization_root_id
}

resource "aws_organizations_policy_attachment" "deny_disable_cloudtrail" {
  policy_id = aws_organizations_policy.deny_disable_cloudtrail.id
  target_id = var.organization_root_id
}

resource "aws_organizations_policy_attachment" "deny_disable_security_services" {
  policy_id = aws_organizations_policy.deny_disable_security_services.id
  target_id = var.organization_root_id
}

resource "aws_organizations_policy_attachment" "require_imdsv2" {
  policy_id = aws_organizations_policy.require_imdsv2.id
  target_id = var.organization_root_id
}

resource "aws_organizations_policy_attachment" "deny_unencrypted_transit" {
  policy_id = aws_organizations_policy.deny_unencrypted_transit.id
  target_id = var.organization_root_id
}
