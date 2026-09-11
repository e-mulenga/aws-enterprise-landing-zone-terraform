# Operational Runbook
## AWS Enterprise Landing Zone

**Portfolio:** Enterprise Cloud Platform — Position 1 of 6
**Owner:** Platform Engineering & Cloud Security
**Cadence:** Review quarterly; update after any infrastructure change

---

## Day-2 Operations Overview

This runbook covers routine operational tasks for the Landing Zone after initial deployment. For incident response procedures, see [`incident-response.md`](incident-response.md). For disaster recovery procedures, see [`disaster-recovery.md`](disaster-recovery.md).

---

## Section 1: Account Management

### 1.1 Add a New AWS Account to the Organisation

**When:** New team, product, or workload needs an isolated AWS environment.

```bash
# Step 1 — Add the new account email to variables.tf and environments/<env>/terraform.tfvars
# e.g. add: analytics_account_email = "analytics@company.com"

# Step 2 — Add the account resource to modules/account-vending/main.tf
# Follow the existing pattern (aws_organizations_account resource)

# Step 3 — Plan and apply only the account-vending module
terraform plan \
  -var-file="environments/prod/terraform.tfvars" \
  -target=module.accounts

terraform apply \
  -var-file="environments/prod/terraform.tfvars" \
  -target=module.accounts

# Step 4 — Retrieve the new account ID
terraform output -json | jq '.account_map.value'

# Step 5 — Update terraform.tfvars with the new account ID
# Then run a full apply to provision IAM Identity Center assignments
terraform apply -var-file="environments/prod/terraform.tfvars"

# Step 6 — Verify security controls in the new account
# GuardDuty and Config auto-enable via org delegation
# Verify:
aws guardduty list-detectors \
  --region af-south-1 \
  --output text \
  # (assume the new account role first)
```

**Expected time:** 10–15 minutes (AWS account creation can take up to 5 minutes).

---

### 1.2 Remove an Account from the Organisation

> ⚠️ **WARNING:** Account removal is irreversible. AWS accounts must be moved to standalone before deletion. All resources inside will remain active and billing continues until explicitly deleted.

```bash
# Step 1 — Raise a Change Advisory Board (CAB) ticket
# Step 2 — Ensure all workloads are migrated or decommissioned
# Step 3 — Remove IAM Identity Center assignments first
terraform apply \
  -var-file="environments/prod/terraform.tfvars" \
  -target=module.iam_identity_center

# Step 4 — Remove the aws_organizations_account resource from Terraform
# (Set lifecycle prevent_destroy = false temporarily for the target account only)

# Step 5 — Terraform apply
terraform apply -var-file="environments/prod/terraform.tfvars"

# Step 6 — Use AWS Console or CLI to formally close the account
aws organizations close-account --account-id <ACCOUNT_ID>
```

---

### 1.3 Grant Temporary Break-Glass Access

**When:** A critical incident requires elevated access that IAM Identity Center sessions cannot provide within their TTL.

```bash
# Create a temporary time-limited role in the target account
aws iam create-role \
  --role-name BreakGlass-Emergency-$(date +%Y%m%d) \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::<MANAGEMENT_ACCOUNT_ID>:root" },
      "Action": "sts:AssumeRole",
      "Condition": {
        "DateLessThan": { "aws:CurrentTime": "<EXPIRY_ISO8601>" },
        "Bool": { "aws:MultiFactorAuthPresent": "true" }
      }
    }]
  }'

# Attach minimum required policy (NOT AdministratorAccess unless absolutely necessary)
aws iam attach-role-policy \
  --role-name BreakGlass-Emergency-$(date +%Y%m%d) \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

# ALWAYS remove the break-glass role within 4 hours
# CloudTrail will record all actions taken — include in post-incident review
```

---

## Section 2: Security Service Operations

### 2.1 Review and Suppress a GuardDuty Finding

```bash
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text --region af-south-1)

# List active HIGH/CRITICAL findings
aws guardduty list-findings \
  --detector-id "${DETECTOR_ID}" \
  --finding-criteria '{"Criterion":{"severity":{"Gte":7},"updatedAt":{"Gte":1}}}' \
  --region af-south-1

# Get full finding detail
aws guardduty get-findings \
  --detector-id "${DETECTOR_ID}" \
  --finding-ids "<FINDING_ID>" \
  --region af-south-1 | jq '.Findings[0] | {Type, Severity, Description, Resource}'

# Suppress a known-good finding (create archive rule)
aws guardduty create-filter \
  --detector-id "${DETECTOR_ID}" \
  --name "Suppress-KnownGood-$(date +%Y%m%d)" \
  --action ARCHIVE \
  --finding-criteria '{"Criterion":{"type":{"Equals":["<FINDING_TYPE>"]},"resource.resourceType":{"Equals":["<RESOURCE_TYPE>"]}}}' \
  --region af-south-1
# NOTE: Suppression must be reviewed by the security team and documented in Jira
```

### 2.2 Check Security Hub Compliance Score

```bash
# View overall posture
aws securityhub describe-hub \
  --region af-south-1 \
  --query '{HubArn:HubArn,AutoEnableControls:AutoEnableControls}'

# List enabled standards and their scores
aws securityhub get-enabled-standards --region af-south-1 \
  | jq '.StandardsSubscriptions[] | {Name: .StandardsArn, Status: .StandardsStatus}'

# List CRITICAL/HIGH NEW findings (unreviewed)
aws securityhub get-findings \
  --filters '{
    "SeverityLabel": [{"Value":"CRITICAL","Comparison":"EQUALS"},{"Value":"HIGH","Comparison":"EQUALS"}],
    "WorkflowStatus": [{"Value":"NEW","Comparison":"EQUALS"}],
    "RecordState": [{"Value":"ACTIVE","Comparison":"EQUALS"}]
  }' \
  --query 'Findings[*].{Title:Title,Severity:Severity.Label,AccountId:AwsAccountId,Resource:Resources[0].Id}' \
  --output table \
  --region af-south-1

# Update finding workflow (after investigation)
aws securityhub batch-update-findings \
  --finding-identifiers '[{"Id":"<FINDING_ID>","ProductArn":"<PRODUCT_ARN>"}]' \
  --workflow '{"Status":"RESOLVED"}' \
  --note '{"Text":"Remediated via Terraform apply — PR #42","UpdatedBy":"engineer@company.com"}' \
  --region af-south-1
```

### 2.3 Verify AWS Config Compliance

```bash
# Summary compliance by rule
aws configservice describe-compliance-by-config-rule \
  --compliance-types NON_COMPLIANT \
  --query 'ComplianceByConfigRules[*].{Rule:ConfigRuleName,Compliance:Compliance.ComplianceType}' \
  --output table \
  --region af-south-1

# Get non-compliant resources for a specific rule
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name s3-bucket-public-read-prohibited \
  --compliance-types NON_COMPLIANT \
  --query 'EvaluationResults[*].{Resource:EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId,ComplianceType:ComplianceType}' \
  --output table \
  --region af-south-1
```

---

## Section 3: KMS Key Operations

### 3.1 Verify Key Rotation Status

```bash
# Check rotation status for all landing-zone CMKs
aws kms list-aliases \
  --query 'Aliases[?starts_with(AliasName, `alias/`) && !starts_with(AliasName, `alias/aws/`)]' \
  --region af-south-1 \
  | jq -r '.Aliases[].TargetKeyId' \
  | while read KEY_ID; do
    ALIAS=$(aws kms list-aliases --key-id "$KEY_ID" --query 'Aliases[0].AliasName' --output text --region af-south-1 2>/dev/null)
    ROTATION=$(aws kms get-key-rotation-status --key-id "$KEY_ID" --query 'KeyRotationEnabled' --output text --region af-south-1 2>/dev/null)
    STATUS=$(aws kms describe-key --key-id "$KEY_ID" --query 'KeyMetadata.KeyState' --output text --region af-south-1 2>/dev/null)
    echo "${ALIAS}: rotation=${ROTATION}, state=${STATUS}"
  done
```

### 3.2 Cancel Accidental Key Deletion

```bash
# If a key was accidentally scheduled for deletion (7–30 day window)
aws kms cancel-key-deletion --key-id <KEY_ID> --region af-south-1
aws kms enable-key --key-id <KEY_ID> --region af-south-1
echo "Key deletion cancelled — verify in CloudTrail"
```

---

## Section 4: CloudTrail Operations

### 4.1 Verify Trail Health

```bash
TRAIL_NAME=$(aws cloudtrail describe-trails \
  --query 'trailList[?IsOrganizationTrail==`true`].Name' \
  --output text --region af-south-1)

aws cloudtrail get-trail-status \
  --name "${TRAIL_NAME}" \
  --region af-south-1 \
  --query '{
    IsLogging: IsLogging,
    LatestDeliveryTime: LatestDeliveryTime,
    LatestDigestDeliveryTime: LatestDigestDeliveryTime,
    LatestDeliveryError: LatestDeliveryError
  }'
```

### 4.2 Search CloudTrail for a Specific Event

```bash
# Find all actions by a specific user in the last 24 hours
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=<USERNAME> \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ) \
  --region af-south-1 \
  | jq '.Events[] | {EventName: .EventName, EventTime: .EventTime, Resources: .Resources}'

# Find all console logins
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ) \
  --region af-south-1 \
  | jq '.Events[] | {User: .Username, Time: .EventTime, Source: .CloudTrailEvent | fromjson | .sourceIPAddress}'

# Validate log file integrity
aws cloudtrail validate-logs \
  --trail-arn "arn:aws:cloudtrail:af-south-1:<ACCOUNT_ID>:trail/${TRAIL_NAME}" \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ) \
  --verbose \
  --region af-south-1
```

---

## Section 5: IAM Identity Center Operations

### 5.1 Assign a User to an Account

```bash
# Get Identity Store ID
IDENTITY_STORE_ID=$(aws sso-admin list-instances \
  --query 'Instances[0].IdentityStoreId' --output text)

SSO_INSTANCE_ARN=$(aws sso-admin list-instances \
  --query 'Instances[0].InstanceArn' --output text)

# Find the user
aws identitystore describe-user \
  --identity-store-id "${IDENTITY_STORE_ID}" \
  --filters '[{"AttributePath":"UserName","AttributeValue":"user@company.com"}]' \
  --query 'Users[0].UserId' --output text

# Get permission set ARN (e.g. DeveloperAccess)
PERM_SET_ARN=$(aws sso-admin list-permission-sets \
  --instance-arn "${SSO_INSTANCE_ARN}" \
  --query 'PermissionSets[0]' --output text)

# Assign user to account with permission set
aws sso-admin create-account-assignment \
  --instance-arn "${SSO_INSTANCE_ARN}" \
  --target-id <ACCOUNT_ID> \
  --target-type AWS_ACCOUNT \
  --permission-set-arn "${PERM_SET_ARN}" \
  --principal-type USER \
  --principal-id <USER_ID>
```

### 5.2 Remove Access (Offboarding)

```bash
# 1. Remove all account assignments for the user
aws sso-admin delete-account-assignment \
  --instance-arn "${SSO_INSTANCE_ARN}" \
  --target-id <ACCOUNT_ID> \
  --target-type AWS_ACCOUNT \
  --permission-set-arn "${PERM_SET_ARN}" \
  --principal-type USER \
  --principal-id <USER_ID>

# 2. Delete the user from the Identity Store (or disable in IdP if federated)
aws identitystore delete-user \
  --identity-store-id "${IDENTITY_STORE_ID}" \
  --user-id <USER_ID>

# 3. Verify no active sessions (check CloudTrail for recent ConsoleLogin)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=<USERNAME> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --region af-south-1
```

---

## Section 6: Monitoring & Alerts Operations

### 6.1 Silence an Alarm During Maintenance

```bash
# Disable alarm actions for a planned maintenance window
aws cloudwatch disable-alarm-actions \
  --alarm-names \
    "<ORG>-<ENV>-unauthorized-api-calls" \
    "<ORG>-<ENV>-root-login" \
  --region af-south-1

# Re-enable after maintenance
aws cloudwatch enable-alarm-actions \
  --alarm-names \
    "<ORG>-<ENV>-unauthorized-api-calls" \
    "<ORG>-<ENV>-root-login" \
  --region af-south-1
```

### 6.2 Test SNS Alert Delivery

```bash
TOPIC_ARN=$(aws sns list-topics \
  --query 'Topics[?contains(TopicArn, `platform-alerts`)].TopicArn' \
  --output text --region af-south-1)

aws sns publish \
  --topic-arn "${TOPIC_ARN}" \
  --subject "[TEST] Landing Zone Alert" \
  --message "This is a test notification from the Landing Zone operational runbook. No action required." \
  --region af-south-1
```

### 6.3 View the Security Dashboard

```bash
# Open CloudWatch dashboard directly
AWS_REGION=af-south-1
DASHBOARD_NAME=$(terraform output -raw monitoring_dashboard_name)
echo "https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards:name=${DASHBOARD_NAME}"
```

---

## Section 7: Terraform Operations

### 7.1 Standard Deployment Pipeline

```
PR opened → terraform-plan.yml runs → plan posted to PR comment
↓
PR merged to main
↓
terraform-apply.yml triggers
↓
DEV: auto-apply
TEST: 1 reviewer approval required
PROD: 2 reviewer approvals + 15-minute wait timer
```

### 7.2 Targeted Resource Apply (Emergency Fix)

```bash
# Apply only specific modules without touching others
terraform apply \
  -var-file="environments/prod/terraform.tfvars" \
  -target=module.guardduty \
  -target=module.security_hub

# Always run a full plan afterwards to confirm state consistency
terraform plan -var-file="environments/prod/terraform.tfvars"
```

### 7.3 Detect and Resolve State Drift

```bash
# Run drift detection
terraform plan \
  -var-file="environments/prod/terraform.tfvars" \
  -detailed-exitcode \
  -refresh=true \
  -no-color 2>&1 | tee drift-report.txt

# Exit code 0 = no changes, 1 = error, 2 = drift detected
echo "Exit code: $?"

# If drift detected, review the plan carefully, then apply
terraform apply -var-file="environments/prod/terraform.tfvars"
```

### 7.4 Import an Existing Resource into State

```bash
# Use when a resource was created manually and needs to be brought under Terraform management
# Example: import an existing GuardDuty detector
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text --region af-south-1)

terraform import \
  -var-file="environments/prod/terraform.tfvars" \
  'module.guardduty.aws_guardduty_detector.main' \
  "${DETECTOR_ID}"

# Verify state is consistent
terraform plan -var-file="environments/prod/terraform.tfvars"
# Expect: No changes
```

---

## Section 8: Maintenance Schedule

| Task | Frequency | Owner | Automation |
|---|---|---|---|
| Review Security Hub findings | Weekly | Cloud Security | Dashboard |
| Review GuardDuty findings | Daily | Cloud Security | SNS alert |
| Run validation script | After every deploy | Platform Eng | CI/CD |
| KMS key rotation check | Monthly | Cloud Security | `validate-landing-zone.sh` |
| CloudTrail log integrity check | Monthly | Cloud Security | Manual CLI |
| Review & prune IAM Identity Center users | Monthly | Platform Eng | Manual |
| Terraform version upgrade | Quarterly | Platform Eng | PR |
| AWS Provider version upgrade | Quarterly | Platform Eng | PR |
| Runbook review | Quarterly | Platform Eng | Manual |
| Well-Architected Review | Annually | Cloud Architect | AWS WA Tool |
| DR test | Bi-annually | Platform Eng | Manual |

---

## Section 9: Useful Aliases & Functions

Add to your shell profile for faster operations:

```bash
# Assume cross-account role
assume_role() {
  local ACCOUNT_ID="$1"
  local ROLE_NAME="${2:-OrganizationAccountAccessRole}"
  local SESSION_NAME="${3:-ops-session}"

  CREDS=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
    --role-session-name "${SESSION_NAME}" \
    --duration-seconds 3600 \
    --query 'Credentials' --output json)

  export AWS_ACCESS_KEY_ID=$(echo "${CREDS}" | jq -r '.AccessKeyId')
  export AWS_SECRET_ACCESS_KEY=$(echo "${CREDS}" | jq -r '.SecretAccessKey')
  export AWS_SESSION_TOKEN=$(echo "${CREDS}" | jq -r '.SessionToken')
  echo "Assumed role in ${ACCOUNT_ID} as ${ROLE_NAME}"
}

# Quick GuardDuty finding summary
gd_summary() {
  local DETECTOR_ID
  DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
  aws guardduty get-findings-statistics \
    --detector-id "${DETECTOR_ID}" \
    --finding-statistic-types COUNT_BY_SEVERITY \
    --finding-criteria '{"Criterion":{"updatedAt":{"Gte":1},"service.archived":{"Eq":["false"]}}}' \
    | jq '.FindingStatistics.CountBySeverity'
}

# Run validation
lz_validate() {
  ENV="${1:-prod}" AWS_REGION="${2:-af-south-1}" \
  bash "$(git rev-parse --show-toplevel)/validation/validate-landing-zone.sh"
}
```

---

*Reviewed: Quarterly | Owner: Platform Engineering*
*Last reviewed: See git log on this file*
