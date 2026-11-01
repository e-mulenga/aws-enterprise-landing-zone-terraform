output "security_group_id" {
  description = "Shared security group attached to every Interface endpoint. Downstream repositories reference it in their egress rules instead of 0.0.0.0/0."
  value       = aws_security_group.interface_endpoints.id
}

output "security_group_arn" {
  description = "ARN of the shared Interface endpoint security group."
  value       = aws_security_group.interface_endpoints.arn
}

output "endpoint_ids" {
  description = "Interface endpoint IDs by stable key (sqs, sns, secretsmanager, logs, eventbridge, kms, monitoring, xray, ecr_api, ecr_dkr, sts). Only the services that were selected appear."
  value       = { for s, key in local.endpoints : key => aws_vpc_endpoint.interface[s].id }
}

output "endpoint_dns_names" {
  description = "DNS names of each endpoint by stable key. Private DNS is enabled, so workloads keep using the normal public service hostname and it resolves to the endpoint inside the VPC."
  value = {
    for s, key in local.endpoints :
    key => [for e in aws_vpc_endpoint.interface[s].dns_entry : e.dns_name]
  }
}

output "service_names" {
  description = "Full PrivateLink service names that were created, for example com.amazonaws.af-south-1.sqs."
  value       = sort([for s in keys(local.endpoints) : data.aws_vpc_endpoint_service.this[s].service_name])
}

output "private_dns_enabled" {
  description = "Always true: endpoint DNS integration is part of this module's contract."
  value       = true
}

output "interface_endpoint_ids" {
  value = {
    for k, v in aws_vpc_endpoint.interface : k => v.id
  }
}
