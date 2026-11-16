# ============================================================
# Module: inspector - Amazon Inspector v2 (vulnerability scanning)
# ============================================================
# Billed per scanned EC2 instance, ECR image and Lambda function, so it is OFF in common.tfvars until a workload needs it.
# Findings flow into Security Hub and the monitoring module's findings feed.
# Region check: Amazon Inspector is listed for af-south-1 (aws-services.info/af-south-1.html, checked 2026-11-13).
# ============================================================

data "aws_caller_identity" "current" {}

resource "aws_inspector2_enabler" "this" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = var.resource_types
}

# Auto-enable for member accounts. Needs the management or delegated administrator account.
resource "aws_inspector2_organization_configuration" "this" {
  count = var.organization_aware ? 1 : 0

  auto_enable {
    ec2    = contains(var.resource_types, "EC2")
    ecr    = contains(var.resource_types, "ECR")
    lambda = contains(var.resource_types, "LAMBDA")
  }

  depends_on = [aws_inspector2_enabler.this]
}
