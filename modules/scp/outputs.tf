output "deny_public_s3_policy_id"            { value = aws_organizations_policy.deny_public_s3.id }
output "deny_root_access_policy_id"          { value = aws_organizations_policy.deny_root_access.id }
output "deny_non_approved_regions_policy_id" { value = aws_organizations_policy.deny_non_approved_regions.id }
output "deny_disable_cloudtrail_policy_id"   { value = aws_organizations_policy.deny_disable_cloudtrail.id }
