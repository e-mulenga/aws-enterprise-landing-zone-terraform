output "route53_zone_id" {
  description = "ID of the existing public hosted zone. null when no domain is configured."
  value       = local.zone_id
}

output "route53_domain_name" {
  description = "Domain name of the hosted zone. null when no domain is configured."
  value       = var.domain_name == "" ? null : var.domain_name
}

output "certificate_arn" {
  description = "Wildcard certificate ARN in the primary region (ALB, API Gateway)."
  value       = one(aws_acm_certificate_validation.regional[*].certificate_arn)
}

output "cloudfront_certificate_arn" {
  description = "Wildcard certificate ARN in us-east-1 (CloudFront)."
  value       = one(aws_acm_certificate_validation.cloudfront[*].certificate_arn)
}
