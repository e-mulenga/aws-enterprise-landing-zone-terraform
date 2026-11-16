output "query_log_group_name" {
  description = "Log group that receives DNS queries, or null when query logging is off."
  value       = one(aws_cloudwatch_log_group.queries[*].name)
}

output "firewall_rule_group_id" {
  description = "DNS Firewall rule group, or null when no domains are blocked."
  value       = one(aws_route53_resolver_firewall_rule_group.this[*].id)
}
