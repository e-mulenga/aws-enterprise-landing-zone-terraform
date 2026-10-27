# ============================================================
# Module: dns - Route 53 foundation (existing hosted zone) + ACM
# ============================================================
# The domain and its hosted zone ALREADY exist. They are only READ here, so
# nothing is recreated, and zone_id / domain_name are exported for every
# future repository.
#
# Certificates (free): one wildcard certificate in the primary region (for
# ALB / API Gateway) and one in us-east-1 (for CloudFront), both validated
# through DNS records in the existing zone.
#
# Failover routing: see docs/consumption-guide.md. Failover records are
# created by the application repository that owns the endpoints, using these
# outputs. Health checks cost about USD 0.50 per month each, so none are
# created here.
# ============================================================

data "aws_route53_zone" "this" {
  count = var.domain_name == "" ? 0 : 1

  name         = var.domain_name
  private_zone = false
}

locals {
  zone_id      = one(data.aws_route53_zone.this[*].zone_id)
  create_certs = var.domain_name != "" && var.create_certificates

  # ACM DNS validation records are identical for the same names in every
  # Region of an account, so the regional certificate drives the DNS records
  # and the us-east-1 certificate reuses them.
}

# ---- Primary region certificate ---------------------------------
resource "aws_acm_certificate" "regional" {
  count = local.create_certs ? 1 : 0

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = { Name = "${var.organization_name}-${var.environment}-wildcard" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = local.create_certs ? {
    for dvo in aws_acm_certificate.regional[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id         = local.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "regional" {
  count = local.create_certs ? 1 : 0

  certificate_arn         = aws_acm_certificate.regional[0].arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}

# ---- us-east-1 certificate (CloudFront) -------------------------
resource "aws_acm_certificate" "cloudfront" {
  count    = local.create_certs && var.create_cloudfront_certificate ? 1 : 0
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = { Name = "${var.organization_name}-${var.environment}-wildcard-cloudfront" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cloudfront" {
  count    = local.create_certs && var.create_cloudfront_certificate ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
