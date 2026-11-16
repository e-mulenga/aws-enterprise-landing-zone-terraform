# ============================================================
# Module: observability - Central CloudWatch cross-account observability (monitoring account side)
# ============================================================
# Creates the sink in this account and lets every account in the organisation link to it, so metrics, logs and traces
# can be viewed from one place. Sinks are free; linked accounts share logs and metrics at no extra charge, and only
# additional traces are billed (CloudWatch cross-account observability documentation).
# Source accounts create their own aws_oam_link towards sink_arn (see the root outputs).
# Region check: Observability Access Manager is listed for af-south-1 (aws-services.info/af-south-1.html, checked 2026-11-13).
# ============================================================

resource "aws_oam_sink" "central" {
  name = "${var.organization_name}-${var.environment}-central"

  tags = { Name = "${var.organization_name}-${var.environment}-central" }
}

resource "aws_oam_sink_policy" "central" {
  sink_identifier = aws_oam_sink.central.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Resource  = "*"
      Action    = ["oam:CreateLink", "oam:UpdateLink"]
      Condition = {
        StringEquals = { "aws:PrincipalOrgID" = var.organization_id }
        "ForAllValues:StringEquals" = {
          "oam:ResourceTypes" = var.resource_types
        }
      }
    }]
  })
}
