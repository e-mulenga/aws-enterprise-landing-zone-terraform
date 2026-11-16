variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "enable_conformance_pack" {
  type        = bool
  default     = false
  description = "Deploy the baseline conformance pack (ten extra managed rules, USD 0.001 per evaluation)."
}

variable "enable_aggregator" {
  type        = bool
  default     = false
  description = "Create an organisation-wide Config aggregator (free). Management or delegated administrator account only."
}

variable "aggregator_regions" {
  type        = list(string)
  default     = ["af-south-1", "eu-west-1"]
  description = "Regions whose Config data the aggregator collects."
}
