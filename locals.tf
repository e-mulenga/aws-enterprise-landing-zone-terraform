locals {
  default_tags = merge(
    {
      Project     = "aws-enterprise-landing-zone"
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Environment = var.environment
      Repository  = "aws-enterprise-landing-zone"
      Portfolio   = "enterprise-cloud-platform"
    },
    var.required_tags
  )

  # Increment when an output name or shape changes in a breaking way.
  contract_schema_version = "2"
}

# ============================================================
# Shared values: computed once here and exposed as root outputs
# ============================================================
locals {
  guardduty_detector_id = try(module.guardduty[0].detector_id, var.existing_guardduty_detector_id == "" ? null : var.existing_guardduty_detector_id)
  config_recorder_name  = try(module.config[0].recorder_name, var.existing_config_recorder_name == "" ? null : var.existing_config_recorder_name)

  region_outputs = {
    af_south_1 = {
      region              = module.networking_af_south_1.region
      vpc_id              = module.networking_af_south_1.vpc_id
      vpc_cidr            = module.networking_af_south_1.vpc_cidr
      vpc_cidr_block      = module.networking_af_south_1.vpc_cidr_block
      azs                 = module.networking_af_south_1.azs
      public_subnet_ids   = module.networking_af_south_1.public_subnet_ids
      private_subnet_ids  = module.networking_af_south_1.private_subnet_ids
      database_subnet_ids = module.networking_af_south_1.database_subnet_ids
      db_subnet_group     = module.networking_af_south_1.database_subnet_group_name
      nat_public_ips      = module.networking_af_south_1.nat_public_ips
    }
    eu_west_1 = {
      region              = module.networking_eu_west_1.region
      vpc_id              = module.networking_eu_west_1.vpc_id
      vpc_cidr            = module.networking_eu_west_1.vpc_cidr
      vpc_cidr_block      = module.networking_eu_west_1.vpc_cidr_block
      azs                 = module.networking_eu_west_1.azs
      public_subnet_ids   = module.networking_eu_west_1.public_subnet_ids
      private_subnet_ids  = module.networking_eu_west_1.private_subnet_ids
      database_subnet_ids = module.networking_eu_west_1.database_subnet_ids
      db_subnet_group     = module.networking_eu_west_1.database_subnet_group_name
      nat_public_ips      = module.networking_eu_west_1.nat_public_ips
    }
  }

}
