# ============================================================
# Module: dns-security - Route 53 Resolver query logging and DNS Firewall blocklist
# ============================================================
# * Query logging: every DNS query made inside the VPC goes to a CloudWatch log group (ingestion and storage are billed by CloudWatch Logs).
# * DNS Firewall: a custom blocklist of domains, attached to the VPC. Created only when blocked_domains is not empty.
#   Firewall rules bill per domain-list entry and per million queries; keep the list short.
# Region check: Amazon Route 53 Resolver is listed for af-south-1 (aws-services.info/af-south-1.html, checked 2026-11-13),
# but that page does not list query logging or DNS Firewall separately. Confirm both in the AWS Region table before enabling.
# ============================================================

resource "aws_cloudwatch_log_group" "queries" {
  count = var.enable_query_logging ? 1 : 0

  name              = "/aws/route53resolver/${var.organization_name}-${var.environment}-${var.vpc_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = { Name = "${var.organization_name}-${var.environment}-${var.vpc_name}-dns-queries" }
}

resource "aws_route53_resolver_query_log_config" "this" {
  count = var.enable_query_logging ? 1 : 0

  name            = "${var.organization_name}-${var.environment}-${var.vpc_name}-queries"
  destination_arn = aws_cloudwatch_log_group.queries[0].arn
}

resource "aws_route53_resolver_query_log_config_association" "this" {
  count = var.enable_query_logging ? 1 : 0

  resolver_query_log_config_id = aws_route53_resolver_query_log_config.this[0].id
  resource_id                  = var.vpc_id
}

# ---- DNS Firewall (custom blocklist) ------------------------------
resource "aws_route53_resolver_firewall_domain_list" "blocked" {
  count = length(var.blocked_domains) > 0 ? 1 : 0

  name    = "${var.organization_name}-${var.environment}-${var.vpc_name}-blocked"
  domains = var.blocked_domains
}

resource "aws_route53_resolver_firewall_rule_group" "this" {
  count = length(var.blocked_domains) > 0 ? 1 : 0

  name = "${var.organization_name}-${var.environment}-${var.vpc_name}-dns-firewall"
}

resource "aws_route53_resolver_firewall_rule" "block" {
  count = length(var.blocked_domains) > 0 ? 1 : 0

  name                    = "block-listed-domains"
  action                  = "BLOCK"
  block_response          = "NXDOMAIN"
  firewall_domain_list_id = aws_route53_resolver_firewall_domain_list.blocked[0].id
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.this[0].id
  priority                = 100
}

resource "aws_route53_resolver_firewall_rule_group_association" "this" {
  count = length(var.blocked_domains) > 0 ? 1 : 0

  name                   = "${var.organization_name}-${var.environment}-${var.vpc_name}"
  firewall_rule_group_id = aws_route53_resolver_firewall_rule_group.this[0].id
  vpc_id                 = var.vpc_id
  priority               = 101
}
