# ============================================================
# AWS Enterprise Landing Zone — Root Variables
# ============================================================

# ---- Identity & Organisation --------------------------------
variable "organization_name" {
  type        = string
  description = "Short name for the AWS Organisation (used in resource naming)."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.organization_name))
    error_message = "organization_name must be 3-30 lowercase alphanumeric characters or hyphens."
  }
}

variable "aws_region" {
  type        = string
  description = "Primary AWS region for all resources."
  default     = "af-south-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment: dev | test | prod."

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "organization_id" {
  description = "AWS Organizations ID (o-xxxxxxxxxx), used in the bucket policy conditions."
  type        = string

  validation {
    condition     = can(regex("^o-[a-z0-9]{10,32}$", var.organization_id))
    error_message = "organization_id must look like o-xxxxxxxxxx."
  }
}

variable "allowed_regions" {
  type = list(string)
  default = [
    "af-south-1",
    "eu-west-1",
    "us-east-1"
  ]
}

# ---- Governance & tagging -------------------------------------
variable "owner" {
  type        = string
  description = "Team or individual responsible for the workload."
}

variable "cost_center" {
  type        = string
  description = "Cost center code for billing allocation."
}

variable "required_tags" {
  type        = map(string)
  description = "Additional tags applied to every resource."
  default     = {}
}

# ---- Account Emails (used by account-vending module) --------
variable "security_account_email" {
  type        = string
  description = "Root email address for the Security AWS account."
}

variable "logging_account_email" {
  type        = string
  description = "Root email address for the Logging AWS account."
}

variable "shared_services_account_email" {
  type        = string
  description = "Root email address for the Shared Services AWS account."
}

variable "development_account_email" {
  type        = string
  description = "Root email address for the Development AWS account."
}

variable "production_account_email" {
  type        = string
  description = "Root email address for the Production AWS account."
}

# ---- Account IDs (populated after accounts are vended) ------

variable "create_member_accounts" {
  type        = bool
  description = "Create the Security / Shared Services / Development / Production accounts. Off for a single personal account."
  default     = true
}

variable "management_account_id" {
  type        = string
  description = "AWS Account ID of the management (root/payer) account."
  default     = ""
}

variable "security_account_id" {
  type        = string
  description = "AWS Account ID of the Security account."
  default     = ""
}

variable "logging_account_id" {
  type        = string
  description = "AWS Account ID of the Logging account."
  default     = ""
}

# ---- Governance services (all free, OFF until you need them) ----------
variable "enable_scp" {
  type        = bool
  description = "Attach the Service Control Policies. Free, but SCPs do not apply to the management account, so they only matter once member accounts exist."
  default     = false
}

variable "enable_identity_center" {
  type        = bool
  description = "Create IAM Identity Center groups and assignments (free). Needs member accounts."
  default     = false
}

variable "enable_ai_governance" {
  type        = bool
  description = "Deploy the AI governance foundation (Bedrock guardrails, invocation logging, and model access policies)."
  default     = true
}

variable "enable_bedrock_invocation_logging" {
  type        = bool
  description = "Enable Amazon Bedrock invocation logging to capture model input/output for audit and compliance purposes."
  default     = true
}

variable "ai_audit_retention_days" {
  type        = number
  description = "Number of days to retain AI/Bedrock audit logs in CloudWatch."
  default     = 30
}

variable "approved_model_arns" {
  type        = list(string)
  description = "Foundation model ARNs workloads may use. Narrow this to the exact models you approve."
  default = [
    "arn:aws:bedrock:*::foundation-model/anthropic.*",
    "arn:aws:bedrock:*::foundation-model/amazon.titan-*",
    "arn:aws:bedrock:*::foundation-model/amazon.nova-*",
  ]
}

# ---- Region Controls ----------------------------------------
variable "allowed_regions" {
  type        = list(string)
  description = "Approved AWS regions. SCPs will deny activity outside this list."
  default     = ["af-south-1", "eu-west-1", "us-east-1"]
}

# ---- IAM Identity Center ------------------------------------
variable "identity_center_admin_group" {
  type        = string
  description = "Name of the IAM Identity Center group for cloud administrators."
  default     = "CloudAdmins"
}

variable "identity_center_custom_permission_sets" {
  description = "Custom permission sets to create in IAM Identity Center. Each key is the permission set name."
  type = map(object({
    description      = string
    session_duration = optional(string, "PT8H")
    managed_policies = optional(list(string), [])
    inline_policy    = optional(string, null)
    tags             = optional(map(string), {})
  }))
  default = {}
}

# ---- Security Services --------------------------------------

# ---- CloudTrail / Logging / Storage / Monitoring ------------
variable "cloudtrail_bucket_name" {
  type        = string
  default     = ""
  description = "Name of the CloudTrail bucket to CREATE. Ignored if existing_buckets.cloudtrail is set."
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log group retention for CloudTrail."
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "existing_buckets" {
  description = "Buckets that are already deployed. Named buckets are looked up (read-only); null ones are created."
  type = object({
    cloudtrail  = optional(string)
    config      = optional(string)
    guardduty   = optional(string)
    access_logs = optional(string)
  })
  default = {}
}

variable "log_archive_expiry_days" {
  type        = number
  description = "Days before CloudTrail/Config archive objects expire. Lower = cheaper. Raise it only if a regulation requires longer retention."
  default     = 730
}

variable "access_log_expiry_days" {
  type        = number
  description = "Days before S3 access/VPC flow log objects and GuardDuty exports expire."
  default     = 90
}

# ---- Encryption ---------------------------------------------

variable "key_rotation_enabled" {
  type        = bool
  description = "Automatic rotation for customer managed keys (ignored when using AWS managed keys)."
  default     = true
}

variable "use_aws_managed_keys" {
  type        = bool
  description = "true = AWS managed keys, no CMKs (dev, test). false = five shared customer managed keys (prod, about USD 5/month)."
  default     = true
}

# ---- Storage ------------------------------------------------
variable "s3_versioning_enabled" {
  type        = bool
  description = "Enable S3 versioning on the centralised log archive bucket."
  default     = true
}

# ---- Backup -------------------------------------------------
variable "backup_retention_days" {
  type        = number
  description = "AWS Backup recovery-point retention period"
  default     = 120

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "backup_retention_days must be between 7 and 365."
  }
}

variable "enable_backup" {
  type        = bool
  description = "Create the backup vault, plan and tag-based selection. The skeleton is free; charges start when resources are tagged BackupEnabled=true."
  default     = true
}

variable "backup_daily_retention_days" {
  type    = number
  default = 7
}

variable "backup_weekly_retention_days" {
  type    = number
  default = 28
}

variable "backup_monthly_retention_days" {
  type    = number
  default = 0
}

variable "backup_cross_region_copy" {
  type        = bool
  description = "Copy backups from af-south-1 to eu-west-1. Adds storage and transfer cost."
  default     = false
}

variable "backup_enable_vault_lock" {
  type        = bool
  description = "Immutable compliance lock. Production only."
  default     = false
}

# ---- Networking ----------------------------------------

# One object per region. CIDRs MUST NOT overlap if you plan to peer the VPCs.
variable "af_south_1" {
  description = "Network settings for af-south-1 (Cape Town)."
  type = object({
    vpc_cidr         = string
    public_subnets   = list(string)
    private_subnets  = list(string)
    database_subnets = list(string)
  })
}

variable "eu_west_1" {
  description = "Network settings for eu-west-1 (Ireland)."
  type = object({
    vpc_cidr         = string
    public_subnets   = list(string)
    private_subnets  = list(string)
    database_subnets = list(string)
  })
}

variable "enable_nat_gateway_primary" {
  type        = bool
  description = "NAT Gateway in the primary Region. About USD 35+/month each; keep false in dev/test."
  default     = false
}

variable "enable_nat_gateway_dr" {
  type        = bool
  description = "NAT Gateway in the DR Region. Keep false."
  default     = false
}

variable "single_nat_gateway" {
  description = "true = one NAT per region (cheaper). false = one NAT per AZ (resilient)."
  type        = bool
  default     = true
}

variable "gateway_endpoints" {
  type        = list(string)
  description = "Free gateway endpoints created in both VPCs."
  default     = ["s3", "dynamodb"]
}

variable "interface_endpoints" {
  type        = list(string)
  description = "Interface endpoints (PrivateLink) created when enabled, by AWS service short name. Tier 1: sqs, sns, secretsmanager, logs, events. Tier 2: kms, monitoring, xray, ecr.api, ecr.dkr, sts. Trim the list to control cost. Billed hourly per AZ plus per GB. See docs/cost-analysis.md."
  default     = ["sqs", "sns", "secretsmanager", "logs", "events", "kms", "monitoring", "xray", "ecr.api", "ecr.dkr", "sts"]
}

variable "enable_interface_endpoints_dr" {
  description = "Whether to create interface VPC endpoints in the DR Region."
  type        = bool
  default     = false
}

variable "interface_endpoints_fallback_to_dr" {
  description = "Whether interface endpoints unavailable in af-south-1 should be created in the DR Region."
  type        = bool
  default     = false
}

variable "restrict_interface_endpoints_to_organization" {
  description = "Whether interface endpoint policies should restrict access to the AWS Organization."
  type        = bool
  default     = false
}

variable "enable_interface_endpoints_primary" {
  description = "Enable Interface VPC Endpoints in primary region"
  type        = bool
  default     = true
}

# ---- VPC Flow Logs (owned here; other repos consume, never recreate) ----
variable "enable_vpc_flow_logs_primary" {
  type        = bool
  description = "Flow logs on the af-south-1 VPC. Keep false until there is traffic worth analysing, to avoid paying for flow logs on an idle dev VPC."
  default     = true
}

variable "enable_vpc_flow_logs_dr" {
  type        = bool
  description = "Flow logs on the eu-west-1 VPC. Keep false — nothing runs there day to day."
  default     = false
}

variable "vpc_flow_logs_destination" {
  type        = string
  description = "cloudwatch, s3, or both. s3 is lowest cost (no per-GB ingestion charge) and is enough for Athena-based investigation; cloudwatch adds real-time metric-filter/alarm capability at a materially higher per-GB cost. See docs/vpc-flow-logs-cost-analysis.md."
  default     = "s3"

  validation {
    condition     = contains(["cloudwatch", "s3", "both"], var.vpc_flow_logs_destination)
    error_message = "vpc_flow_logs_destination must be one of: cloudwatch, s3, both."
  }
}

variable "vpc_flow_logs_traffic_type" {
  type        = string
  description = "ALL, ACCEPT, or REJECT. REJECT-only cuts volume/cost substantially and still catches most security-relevant signal (denied connections); use ALL when full network troubleshooting is needed."
  default     = "REJECT"

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.vpc_flow_logs_traffic_type)
    error_message = "vpc_flow_logs_traffic_type must be one of: ALL, ACCEPT, REJECT."
  }
}

variable "vpc_flow_logs_retention_days" {
  type        = number
  description = "CloudWatch Log group retention (only relevant when the destination includes cloudwatch)."
  default     = 14
}

# ---- Budget Alerting ----------------------------------------

variable "budget_alert_email" {
  type        = string
  description = "Email address that receives budget alert notifications."
  default     = ""
}

variable "alert_email" {
  type        = string
  description = "Email for security alerts and budget notifications."
  default     = ""
}

variable "monthly_budget_usd" {
  type        = number
  description = "Monthly AWS spend budget. Alerts at 80% forecast and 100% actual."
  default     = 10
}

variable "enable_monitoring" {
  type        = bool
  description = "Dashboard (first three are free), SNS topic and monthly budget (first two are free)."
  default     = true
}

variable "enable_security_alarms" {
  type        = bool
  description = "CIS-style CloudWatch alarms (about USD 0.10 each). Needs a CloudTrail log group."
  default     = true
}

# ---- DNS (existing Route 53 zone) ------------------------------------
variable "route53_domain_name" {
  type        = string
  description = "Existing public hosted zone, for example example.com. Empty = DNS foundation off."
  default     = ""
}

variable "create_acm_certificates" {
  type        = bool
  description = "Request free wildcard ACM certificates (regional + us-east-1) validated in the existing zone."
  default     = true
}

# ---- Platform: GitHub OIDC and ECR -------------------------------------
variable "github_oidc_mode" {
  type        = string
  description = "disabled | lookup (provider already exists) | create."
  default     = "disabled"

  validation {
    condition     = contains(["disabled", "lookup", "create", "existing"], var.github_oidc_mode)
    error_message = "github_oidc_mode must be disabled, lookup or create."
  }
}

variable "github_oidc_roles" {
  description = "Optional GitHub Actions roles, trusted only for the listed repo subjects."
  type = map(object({
    description          = optional(string, "GitHub Actions role")
    subjects             = list(string)
    policy_arns          = optional(list(string), [])
    max_session_duration = optional(number, 3600)
  }))
  default = {}
}

variable "enable_ecr" {
  type        = bool
  description = "Shared ECR repositories. Empty repositories are free; storage only is billed."
  default     = true
}

variable "ecr_keep_last_images" {
  type    = number
  default = 10
}

# ---- Audit & detection services (cost money, OFF by default) -----------
variable "enable_cloudtrail" {
  type        = bool
  description = "Create the trail with Terraform. false when a trail already exists (console / other stack)."
  default     = false
}

variable "is_organization_trail" {
  type        = bool
  description = "Organization trail. Needs the management or a delegated admin account."
  default     = false
}

variable "cloudtrail_data_events_enabled" {
  type        = bool
  description = "S3 and Lambda data events (billed per event)."
  default     = false
}

variable "cloudtrail_insights_enabled" {
  type        = bool
  description = "CloudTrail Insights (billed per event analysed)."
  default     = false
}

variable "existing_cloudtrail_log_group" {
  type        = string
  description = "CloudWatch Logs group of an existing trail, used by the dashboard and alarms when this stack does not create the trail."
  default     = ""
}

variable "enable_config" {
  type        = bool
  description = "Create the AWS Config recorder, delivery channel and rules (billed per item and per evaluation). AWS allows one recorder per Region."
  default     = false
}

variable "existing_config_recorder_name" {
  type        = string
  description = "Name of an existing Config recorder, re-exported as config_recorder_name when enable_config = false."
  default     = ""
}

variable "config_recording_frequency" {
  type    = string
  default = "CONTINUOUS"
}

variable "config_rule_set" {
  type        = string
  description = "core = 9 rules, full = 20 rules."
  default     = "core"
}

variable "guardduty_enabled" {
  type        = bool
  description = "Create / manage GuardDuty. 30-day free trial, then usage-based."
  default     = false
}

variable "create_guardduty_detector" {
  type        = bool
  description = "false = a detector already exists in the Region; look it up instead."
  default     = true
}

variable "existing_guardduty_detector_id" {
  type        = string
  description = "Detector ID re-exported as guardduty_detector_id when guardduty_enabled = false."
  default     = ""
}

variable "guardduty_organization_aware" {
  type    = bool
  default = false
}

variable "securityhub_enabled" {
  type        = bool
  description = "Enable Security Hub. 30-day free trial, then billed per protected resource."
  default     = false
}

variable "securityhub_standards" {
  type        = list(string)
  description = "Standards to subscribe to: fsbp, cis, nist."
  default     = ["fsbp"]
}

variable "securityhub_organization_aware" {
  type    = bool
  default = false
}

# ---- Additions: detective and cost controls (see docs/COST.md for the price of each) ----
variable "enable_access_analyzer" {
  type        = bool
  description = "IAM Access Analyzer for external access (free)."
  default     = true
}

variable "access_analyzer_type" {
  type        = string
  description = "ORGANIZATION (management or delegated administrator account) or ACCOUNT."
  default     = "ORGANIZATION"
}

variable "enable_inspector" {
  type        = bool
  description = "Amazon Inspector v2 scanning. Billed per scanned image, function or instance, so it stays off until a workload needs it."
  default     = false
}

variable "inspector_resource_types" {
  type        = list(string)
  description = "What Inspector scans: EC2, ECR, LAMBDA, LAMBDA_CODE."
  default     = ["ECR", "LAMBDA"]
}

variable "enable_macie" {
  type        = bool
  description = "Amazon Macie sensitive data discovery. Billed per bucket and per GB inspected, so it stays off until needed."
  default     = false
}

variable "enable_config_conformance_pack" {
  type        = bool
  description = "Baseline Config conformance pack (ten extra managed rules, USD 0.001 per evaluation)."
  default     = false
}

variable "enable_config_aggregator" {
  type        = bool
  description = "Organisation-wide Config aggregator (free)."
  default     = false
}

variable "enable_securityhub_finding_aggregator" {
  type        = bool
  description = "Aggregate Security Hub findings from eu-west-1 into the primary Region (free). Security Hub must be enabled in eu-west-1 first."
  default     = false
}

variable "securityhub_alert_severity_labels" {
  type        = list(string)
  description = "Severity labels of new Security Hub findings that are e-mailed."
  default     = ["CRITICAL", "HIGH"]
}

variable "enable_tag_policy" {
  type        = bool
  description = "Organisation tag policy (free, report-only unless tag_policy_enforced_for is set). Needs the TAG_POLICY policy type enabled on the organisation root."
  default     = false
}

variable "tag_policy_enforced_for" {
  type        = list(string)
  description = "Resource types where the tag policy blocks non-compliant tagging, for example [\"ec2:instance\"]. Empty = report only."
  default     = []
}

variable "enable_ou_scps" {
  type        = bool
  description = "Attach the built-in per-OU SCPs: a Sandbox cost guard and a Workloads telemetry guard."
  default     = true
}

variable "ou_scps" {
  description = "Extra per-OU SCPs, by policy name. target_ous are OU keys (security, infrastructure, audit, sandbox, workloads, development, production). statements_json is a JSON array of IAM policy statements, for example jsonencode([...])."
  type = map(object({
    description     = string
    target_ous      = list(string)
    statements_json = string
  }))
  default = {}
}

variable "enable_cost_reporting" {
  type        = bool
  description = "Daily Cost and Usage Report (Parquet) to an S3 bucket in us-east-1. The report is free; storage is a few cents."
  default     = false
}

variable "cost_anomaly_threshold_usd" {
  type        = number
  description = "Minimum absolute impact in USD before a Cost Anomaly Detection e-mail is sent."
  default     = 5
}

variable "enable_dns_query_logging_primary" {
  type        = bool
  description = "Route 53 Resolver query logging for the af-south-1 VPC (billed as CloudWatch Logs ingestion and storage)."
  default     = false
}

variable "dns_blocked_domains" {
  type        = list(string)
  description = "Domains blocked by Route 53 DNS Firewall in the af-south-1 VPC, for example [\"*.example-bad.com.\"]. Empty = no firewall."
  default     = []
}

variable "enable_central_observability" {
  type        = bool
  description = "CloudWatch cross-account observability sink for the organisation (free)."
  default     = false
}

variable "interface_endpoint_az_count" {
  type        = number
  description = "AZs per interface endpoint. 1 halves the hourly cost; endpoints are billed per AZ per hour. Use 2 only for production workloads that need AZ-local resilience."
  default     = 1

  validation {
    condition     = var.interface_endpoint_az_count >= 1 && var.interface_endpoint_az_count <= 2
    error_message = "interface_endpoint_az_count must be 1 or 2."
  }
}

variable "dr_kms_replicas_enabled" {
  type        = bool
  description = "Create multi-Region customer managed keys with eu-west-1 replicas so DR repositories can use the same key material. Only meaningful when use_aws_managed_keys = false. Changing multi_region on an existing key forces replacement."
  default     = false
}

variable "enable_cost_anomaly_detection" {
  type        = bool
  description = "AWS Cost Anomaly Detection monitor and e-mail subscription (free)."
  default     = true
}

variable "state_bucket_name" {
  type        = string
  description = "Name of the S3 bucket holding this stack's Terraform state. Echoed in the contract so downstream repositories need not ask for it. Not a secret."
  default     = "<landing-zone-state-bucket>"
}

variable "state_key" {
  type        = string
  description = "S3 key of this stack's state file (echoed in the contract)."
  default     = "your-s3-key"
}

variable "state_region" {
  type        = string
  description = "Region of the state bucket (echoed in the contract)."
  default     = "<your-bucket-region>"
}

variable "allow_public_web_ingress" {
  description = "Open ports 80 and 443 to the internet on the default security group. Keep false in all environments."
  type        = bool
  default     = false
}

variable "securityhub_standards" {
  type    = list(string)
  default = []
}

variable "enable_scp" {
  type    = bool
  default = false
}

variable "enable_identity_center" {
  type    = bool
  default = true
}
