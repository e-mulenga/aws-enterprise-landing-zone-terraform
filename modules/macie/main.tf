# ============================================================
# Module: macie - Amazon Macie (sensitive data discovery in S3)
# ============================================================
# Billed per S3 bucket monitored and per GB of objects inspected, so it is OFF in common.tfvars.
# Region check: Amazon Macie is listed for af-south-1 (aws-services.info/af-south-1.html, checked 2026-11-13;
# AWS announced availability in Cape Town in December 2020).
# ============================================================

resource "aws_macie2_account" "this" {
  finding_publishing_frequency = var.finding_publishing_frequency
  status                       = "ENABLED"
}
