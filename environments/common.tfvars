# ============================================================
# Shared posture: applied to dev, test AND prod by scripts/tf.sh.
# Same controls everywhere; only identity (account e-mails, CIDRs, budget) differs per environment.
# Cost rule: anything that bills per hour stays off until a workload needs it.
# ============================================================

aws_region      = "af-south-1"
allowed_regions = ["af-south-1", "eu-west-1", "us-east-1"]

# ---- Encryption: one strategy for every environment ----
# AWS managed keys cost nothing. Set false to create the five shared CMKs (USD 1/month each, per environment).
use_aws_managed_keys    = true
key_rotation_enabled    = true
dr_kms_replicas_enabled = false

# ---- Governance ----
enable_scp             = true
enable_identity_center = false
enable_ai_governance   = false
create_member_accounts = true

# ---- Detective controls (existing org-level services are adopted, not recreated) ----
enable_cloudtrail              = true
is_organization_trail          = true
cloudtrail_data_events_enabled = false
cloudtrail_insights_enabled    = false
enable_config                  = true
config_recording_frequency     = "DAILY"
config_rule_set                = "core"
guardduty_enabled              = true
securityhub_enabled            = true
securityhub_standards          = ["fsbp"]

# ---- Retention (lower = cheaper) ----
log_archive_expiry_days = 730
access_log_expiry_days  = 90
log_retention_days      = 90

# ---- Backup ----
enable_backup                 = true
backup_daily_retention_days   = 7
backup_weekly_retention_days  = 28
backup_monthly_retention_days = 0
backup_cross_region_copy      = false
backup_enable_vault_lock      = false

# ---- Networking: NAT and interface endpoints are the big fixed costs, so they are off ----
enable_nat_gateway_primary                   = false
enable_nat_gateway_dr                        = false
single_nat_gateway                           = true
gateway_endpoints                            = ["s3", "dynamodb"]
enable_interface_endpoints_primary           = false
enable_interface_endpoints_dr                = false
interface_endpoint_az_count                  = 1
restrict_interface_endpoints_to_organization = true

# ---- Flow logs: denied traffic only, to S3 ----
enable_vpc_flow_logs_primary = true
enable_vpc_flow_logs_dr      = false
vpc_flow_logs_destination    = "s3"
vpc_flow_logs_traffic_type   = "REJECT"

# ---- Monitoring ----
enable_monitoring             = true
enable_security_alarms        = true
enable_cost_anomaly_detection = true

# ---- Other ----
create_acm_certificates = true
enable_ecr              = true
ecr_keep_last_images    = 10
github_oidc_mode        = "create"
