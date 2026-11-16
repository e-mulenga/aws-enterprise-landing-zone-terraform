# ============================================================
# Module: tag-policies - Organisation tag policy
# ============================================================
# Standardises tag keys and the allowed values of the Environment tag so cost allocation reports stay clean.
# The policy is REPORT-ONLY by default: non-compliant resources show up in the tag compliance report but nothing is blocked.
# Add resource types to enforced_for to make it block. A tag policy costs nothing.
# Prerequisite: the TAG_POLICY policy type must be enabled on the organisation root (check block in the root module).
# ============================================================

locals {
  environment_tag = merge(
    {
      tag_key   = { "@@assign" = "Environment" }
      tag_value = { "@@assign" = var.allowed_environment_values }
    },
    length(var.enforced_for) == 0 ? {} : { enforced_for = { "@@assign" = var.enforced_for } }
  )
}

resource "aws_organizations_policy" "tags" {
  name        = "${var.organization_name}-standard-tags"
  description = "Tag key capitalisation and allowed Environment values."
  type        = "TAG_POLICY"

  content = jsonencode({
    tags = {
      Environment = local.environment_tag
      ManagedBy = {
        tag_key   = { "@@assign" = "ManagedBy" }
        tag_value = { "@@assign" = ["Terraform"] }
      }
      CostCenter = {
        tag_key = { "@@assign" = "CostCenter" }
      }
      Owner = {
        tag_key = { "@@assign" = "Owner" }
      }
    }
  })
}

resource "aws_organizations_policy_attachment" "root" {
  policy_id = aws_organizations_policy.tags.id
  target_id = var.organization_root_id
}
