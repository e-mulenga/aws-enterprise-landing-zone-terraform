output "conformance_pack_name" {
  description = "Name of the baseline conformance pack, or null when it is off."
  value       = one(aws_config_conformance_pack.baseline[*].name)
}

output "aggregator_name" {
  description = "Name of the organisation Config aggregator, or null when it is off."
  value       = one(aws_config_configuration_aggregator.organization[*].name)
}
