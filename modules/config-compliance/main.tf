# ============================================================
# Module: config-compliance - Config conformance pack and aggregator
# ============================================================
# * Conformance pack: ten CIS-style managed rules that the config module does NOT already create, so no rule is
#   evaluated (and billed) twice. Each rule evaluation bills USD 0.001 (first 100,000 per month, US East; AWS Config pricing
#   page, checked 2026-11-13), so the pack is OFF until you want the extra coverage.
# * Aggregator: one view of Config data across the organisation. The aggregator itself is free.
# Needs the Config recorder from the config module (or an existing one) in the same Region.
# Region check: AWS Config is listed for af-south-1 (aws-services.info/af-south-1.html, checked 2026-11-13).
# ============================================================

locals {
  pack_rules = {
    root-account-mfa-enabled          = { identifier = "ROOT_ACCOUNT_MFA_ENABLED", parameters = {} }
    access-keys-rotated               = { identifier = "ACCESS_KEYS_ROTATED", parameters = { maxAccessKeyAge = "90" } }
    multi-region-cloudtrail-enabled   = { identifier = "MULTI_REGION_CLOUD_TRAIL_ENABLED", parameters = {} }
    vpc-default-security-group-closed = { identifier = "VPC_DEFAULT_SECURITY_GROUP_CLOSED", parameters = {} }
    ebs-snapshot-public-restorable    = { identifier = "EBS_SNAPSHOT_PUBLIC_RESTORABLE_CHECK", parameters = {} }
    rds-snapshot-public-prohibited    = { identifier = "RDS_SNAPSHOT_PUBLIC_PROHIBITED", parameters = {} }
    rds-instance-public-access-check  = { identifier = "RDS_INSTANCE_PUBLIC_ACCESS_CHECK", parameters = {} }
    s3-account-level-public-access    = { identifier = "S3_ACCOUNT_LEVEL_PUBLIC_ACCESS_BLOCKS", parameters = {} }
    lambda-function-public-access     = { identifier = "LAMBDA_FUNCTION_PUBLIC_ACCESS_PROHIBITED", parameters = {} }
    iam-policy-no-admin-statements    = { identifier = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS", parameters = {} }
  }

  template_body = yamlencode({
    Resources = {
      for name, rule in local.pack_rules : replace(title(replace(name, "-", " ")), " ", "") => {
        Type = "AWS::Config::ConfigRule"
        Properties = merge(
          {
            ConfigRuleName = "${var.organization_name}-${var.environment}-${name}"
            Source = {
              Owner            = "AWS"
              SourceIdentifier = rule.identifier
            }
          },
          length(rule.parameters) == 0 ? {} : { InputParameters = rule.parameters }
        )
      }
    }
  })
}

resource "aws_config_conformance_pack" "baseline" {
  count = var.enable_conformance_pack ? 1 : 0

  name          = "${var.organization_name}-${var.environment}-baseline"
  template_body = local.template_body
}

# ---- Organisation aggregator ----------------------------------
resource "aws_iam_role" "aggregator" {
  count = var.enable_aggregator ? 1 : 0

  name = "${var.organization_name}-${var.environment}-config-aggregator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "aggregator" {
  count = var.enable_aggregator ? 1 : 0

  role       = aws_iam_role.aggregator[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

resource "aws_config_configuration_aggregator" "organization" {
  count = var.enable_aggregator ? 1 : 0

  name = "${var.organization_name}-${var.environment}-organization"

  organization_aggregation_source {
    all_regions = false
    regions     = var.aggregator_regions
    role_arn    = aws_iam_role.aggregator[0].arn
  }

  depends_on = [aws_iam_role_policy_attachment.aggregator]
}
