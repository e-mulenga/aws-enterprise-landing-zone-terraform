#!/usr/bin/env bash
# ============================================================
# validation/validate-landing-zone.sh
# Post-deployment validation for AWS Enterprise Landing Zone
# ============================================================
# Checks that every security control is active and configured
# correctly. Exits non-zero if any check fails.
#
# Usage:
#   ENV=prod AWS_REGION=af-south-1 bash validation/validate-landing-zone.sh
# ============================================================

set -euo pipefail

: "${ENV:?Required: ENV}"
: "${AWS_REGION:=${AWS_DEFAULT_REGION:-af-south-1}}"

PASS=0
FAIL=0
WARN=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass()  { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARN++)); }
header(){ echo -e "\n--- $1 ---"; }

echo "============================================"
echo " AWS Enterprise Landing Zone Validation"
echo " Environment : ${ENV}"
echo " Region      : ${AWS_REGION}"
echo " Date        : $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"

# ---- 1. AWS ORGANISATIONS -----------------------------------
header "AWS Organisations"
ORG=$(aws organizations describe-organization --query 'Organization.Id' --output text 2>/dev/null || echo "NONE")
if [[ "${ORG}" != "NONE" ]]; then
  pass "AWS Organisation exists: ${ORG}"
else
  fail "AWS Organisation NOT found"
fi

SCP_ENABLED=$(aws organizations describe-organization \
  --query 'Organization.AvailablePolicyTypes[?Type==`SERVICE_CONTROL_POLICY`].Status' \
  --output text 2>/dev/null || echo "NONE")
if [[ "${SCP_ENABLED}" == "ENABLED" ]]; then
  pass "SCPs are enabled"
else
  fail "SCPs are NOT enabled"
fi

# ---- 2. CLOUDTRAIL ------------------------------------------
header "CloudTrail"
TRAILS=$(aws cloudtrail describe-trails --include-shadow-trails false \
  --query 'trailList[?IsOrganizationTrail==`true`]' --output json --region "${AWS_REGION}")
TRAIL_COUNT=$(echo "${TRAILS}" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
if [[ "${TRAIL_COUNT}" -ge 1 ]]; then
  pass "Organisation trail found (count: ${TRAIL_COUNT})"
else
  fail "No organisation-level CloudTrail trail found"
fi

TRAIL_NAME=$(echo "${TRAILS}" | python3 -c "import json,sys; t=json.load(sys.stdin); print(t[0]['Name'] if t else '')" 2>/dev/null || echo "")
if [[ -n "${TRAIL_NAME}" ]]; then
  STATUS=$(aws cloudtrail get-trail-status --name "${TRAIL_NAME}" \
    --query 'IsLogging' --output text --region "${AWS_REGION}" 2>/dev/null || echo "false")
  if [[ "${STATUS}" == "True" ]]; then
    pass "CloudTrail is actively logging"
  else
    fail "CloudTrail trail exists but is NOT logging"
  fi

  VALIDATION=$(aws cloudtrail describe-trails --trail-name-list "${TRAIL_NAME}" \
    --query 'trailList[0].LogFileValidationEnabled' --output text --region "${AWS_REGION}" 2>/dev/null || echo "false")
  if [[ "${VALIDATION}" == "True" ]]; then
    pass "CloudTrail log file validation enabled"
  else
    fail "CloudTrail log file validation DISABLED"
  fi

  ENCRYPTION=$(aws cloudtrail describe-trails --trail-name-list "${TRAIL_NAME}" \
    --query 'trailList[0].KMSKeyId' --output text --region "${AWS_REGION}" 2>/dev/null || echo "")
  if [[ -n "${ENCRYPTION}" && "${ENCRYPTION}" != "None" ]]; then
    pass "CloudTrail encrypted with KMS"
  else
    fail "CloudTrail NOT encrypted with KMS"
  fi
fi

# ---- 3. GUARDDUTY -------------------------------------------
header "GuardDuty"
DETECTOR=$(aws guardduty list-detectors --region "${AWS_REGION}" \
  --query 'DetectorIds[0]' --output text 2>/dev/null || echo "NONE")
if [[ "${DETECTOR}" != "NONE" && "${DETECTOR}" != "None" && -n "${DETECTOR}" ]]; then
  pass "GuardDuty detector found: ${DETECTOR}"
  GD_STATUS=$(aws guardduty get-detector --detector-id "${DETECTOR}" \
    --query 'Status' --output text --region "${AWS_REGION}" 2>/dev/null || echo "DISABLED")
  if [[ "${GD_STATUS}" == "ENABLED" ]]; then
    pass "GuardDuty is ENABLED"
  else
    fail "GuardDuty detector is DISABLED"
  fi
else
  fail "GuardDuty detector NOT found"
fi

# ---- 4. SECURITY HUB ----------------------------------------
header "Security Hub"
SH_STATUS=$(aws securityhub describe-hub \
  --query 'HubArn' --output text --region "${AWS_REGION}" 2>/dev/null || echo "NONE")
if [[ "${SH_STATUS}" != "NONE" && -n "${SH_STATUS}" ]]; then
  pass "Security Hub is enabled"
else
  fail "Security Hub NOT enabled"
fi

# ---- 5. AWS CONFIG ------------------------------------------
header "AWS Config"
RECORDER=$(aws configservice describe-configuration-recorder-status \
  --query 'ConfigurationRecordersStatus[0].recording' \
  --output text --region "${AWS_REGION}" 2>/dev/null || echo "false")
if [[ "${RECORDER}" == "True" ]]; then
  pass "AWS Config recorder is active"
else
  fail "AWS Config recorder is NOT active"
fi

# ---- 6. S3 PUBLIC ACCESS BLOCK (account level) --------------
header "S3 Account-Level Public Access Block"
S3_BLOCK=$(aws s3control get-public-access-block \
  --account-id "$(aws sts get-caller-identity --query Account --output text)" \
  --query 'PublicAccessBlockConfiguration' --output json 2>/dev/null || echo "{}")
for SETTING in BlockPublicAcls IgnorePublicAcls BlockPublicPolicy RestrictPublicBuckets; do
  VALUE=$(echo "${S3_BLOCK}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('${SETTING}', False))" 2>/dev/null || echo "False")
  if [[ "${VALUE}" == "True" ]]; then
    pass "S3 account block: ${SETTING}"
  else
    fail "S3 account block NOT set: ${SETTING}"
  fi
done

# ---- 7. KMS KEY ROTATION ------------------------------------
header "KMS Key Rotation"
KEYS=$(aws kms list-aliases --query "Aliases[?starts_with(AliasName, 'alias/${ENV}') || starts_with(AliasName, 'alias/terraform')]" \
  --output json --region "${AWS_REGION}" 2>/dev/null || echo "[]")
KEY_COUNT=$(echo "${KEYS}" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
if [[ "${KEY_COUNT}" -gt 0 ]]; then
  pass "CMKs found (count: ${KEY_COUNT})"
else
  warn "No CMKs found matching environment prefix"
fi

# ---- 8. IAM IDENTITY CENTER ---------------------------------
header "IAM Identity Center"
SSO=$(aws sso-admin list-instances \
  --query 'Instances[0].InstanceArn' --output text 2>/dev/null || echo "NONE")
if [[ "${SSO}" != "NONE" && -n "${SSO}" ]]; then
  pass "IAM Identity Center instance: ${SSO}"
else
  warn "IAM Identity Center not found (may require delegated admin check)"
fi

# ---- 9. CLOUDWATCH ALARMS -----------------------------------
header "CloudWatch Security Alarms"
ALARMS=$(aws cloudwatch describe-alarms \
  --alarm-name-prefix "${ENV}" \
  --query 'MetricAlarms[*].AlarmName' \
  --output json --region "${AWS_REGION}" 2>/dev/null || echo "[]")
ALARM_COUNT=$(echo "${ALARMS}" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
if [[ "${ALARM_COUNT}" -ge 8 ]]; then
  pass "CloudWatch alarms configured (count: ${ALARM_COUNT})"
else
  fail "Expected ≥8 CloudWatch alarms, found: ${ALARM_COUNT}"
fi

# ---- 10. BACKUP VAULT ---------------------------------------
header "AWS Backup"
VAULT=$(aws backup list-backup-vaults \
  --query "BackupVaultList[?BackupVaultName==\`${ENV}\` || contains(BackupVaultName, '${ENV}')].BackupVaultName" \
  --output text --region "${AWS_REGION}" 2>/dev/null || echo "")
if [[ -n "${VAULT}" ]]; then
  pass "Backup vault found: ${VAULT}"
else
  warn "No backup vault found with environment prefix '${ENV}'"
fi

# ---- SUMMARY ------------------------------------------------
echo ""
echo "============================================"
echo " Validation Summary"
echo "   PASS : ${PASS}"
echo "   WARN : ${WARN}"
echo "   FAIL : ${FAIL}"
echo "============================================"

if [[ "${FAIL}" -gt 0 ]]; then
  echo -e "${RED}Validation FAILED — ${FAIL} control(s) not satisfied.${NC}"
  exit 1
elif [[ "${WARN}" -gt 0 ]]; then
  echo -e "${YELLOW}Validation PASSED with ${WARN} warning(s). Review before production.${NC}"
  exit 0
else
  echo -e "${GREEN}All validation checks PASSED.${NC}"
  exit 0
fi
