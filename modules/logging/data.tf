data "aws_caller_identity" "current" {}

# ---- Look up buckets that are already deployed ---------------
# These fail the plan if the named bucket does not exist, which is the
# "check" that the pre-existing bucket is really there.

data "aws_s3_bucket" "cloudtrail" {
  count  = local.create_cloudtrail ? 0 : 1
  bucket = local.existing.cloudtrail
}

data "aws_s3_bucket" "config" {
  count  = local.create_config ? 0 : 1
  bucket = local.existing.config
}

data "aws_s3_bucket" "guardduty" {
  count  = local.create_guardduty ? 0 : 1
  bucket = local.existing.guardduty
}

data "aws_s3_bucket" "access_logs" {
  count  = local.create_access_logs ? 0 : 1
  bucket = local.existing.access_logs
}
