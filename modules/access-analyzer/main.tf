# ============================================================
# Module: access-analyzer - IAM Access Analyzer (external access)
# ============================================================
# External access analysis is free. Run it with type = ORGANIZATION from the management account (or a delegated
# administrator) to cover every member account, or ACCOUNT for a single account.
# Findings reach Security Hub on their own and the monitoring module copies them to the findings log group.
# The unused-access analyzer is billed per IAM role and user analysed, so it is not created here.
# Region check: IAM Access Analyzer is listed for af-south-1 (aws-services.info/af-south-1.html, checked 2026-11-13),
# so no Ireland alias is used.
# ============================================================

resource "aws_accessanalyzer_analyzer" "external" {
  analyzer_name = "${var.organization_name}-${var.environment}-external-access"
  type          = var.analyzer_type

  tags = { Name = "${var.organization_name}-${var.environment}-external-access" }
}
