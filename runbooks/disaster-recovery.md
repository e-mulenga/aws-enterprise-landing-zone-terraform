# Disaster Recovery Runbook
## AWS Enterprise Landing Zone

**Portfolio:** Enterprise Cloud Platform  
**Strategy:** Pilot Light with warm-standby capability  
**Primary Region:** af-south-1 (Cape Town)  
**DR Region:** eu-west-1 (Ireland)  

---

## Recovery Objectives

| Tier | RTO | RPO | Examples |
|---|---|---|---|
| Tier 0 — Critical | 1 hour | 15 min | Security controls, CloudTrail, GuardDuty |
| Tier 1 — High | 4 hours | 1 hour | IAM Identity Center, AWS Config, Logging |
| Tier 2 — Standard | 24 hours | 4 hours | Monitoring dashboards, backup vaults |
| Tier 3 — Low | 72 hours | 24 hours | Cost reports, non-critical alerts |

---

## Architecture DR Design

```
PRIMARY (af-south-1)                    DR (eu-west-1)
┌─────────────────────────┐             ┌────────────────────── ──┐
│  Organisation Trail     │──S3 CRR──▶ │  S3 Log Replica         │
│  GuardDuty (Primary)    │            │   GuardDuty (Secondary) │
│  Security Hub           │            │   Security Hub (standby) │
│  KMS CMKs               │──replica─▶ │  KMS Multi-Region Keys │
│  Config Recorder        │            │   Config Recorder        │
│  CloudWatch Alarms      │            │   CloudWatch Alarms      │
└─────────────────────────┘            └─────────────────────────┘
        │                                        │
        └──────── AWS Organizations ─────────────┘
                  (Global — no DR needed)
```

---

## Scenario 1: Region-Level Failure (Primary Region Down)

### Detection
- CloudWatch cross-region health alarm triggers
- AWS Service Health Dashboard shows af-south-1 impairment
- GuardDuty findings stop arriving in Security Hub

### DR Activation Procedure

**Step 1 — Declare DR Event**
```bash
# Confirm region is impaired
aws health describe-events \
  --filter '{"regions":["af-south-1"],"eventStatusCodes":["open","upcoming"]}' \
  --region us-east-1
```

**Step 2 — Activate DR Terraform workspace**
```bash
cd environments/prod
# Switch backend to DR region state
terraform workspace select dr-eu-west-1

# Apply DR-specific tfvars
terraform plan \
  -var-file="terraform.tfvars" \
  -var="aws_region=eu-west-1" \
  -var="is_dr_activation=true" \
  -out=dr.tfplan

terraform apply dr.tfplan
```

**Step 3 — Verify security controls in DR region**
```bash
ENV=prod AWS_REGION=eu-west-1 bash validation/validate-landing-zone.sh
```

**Step 4 — Update DNS / Route 53 (if applicable)**

**Step 5 — Notify stakeholders**

---

## Scenario 2: Terraform State Corruption or Loss

### Detection
- `terraform plan` returns `state file not found` or checksum error
- DynamoDB lock table corrupted
- S3 bucket deleted or versioning disabled

### Recovery Procedure

**Step 1 — Restore state from S3 versioning**
```bash
# List all state file versions
aws s3api list-object-versions \
  --bucket "${ORG}-terraform-state-${ENV}" \
  --prefix "landing-zone/${ENV}/terraform.tfstate" \
  --query 'Versions[*].{VersionId:VersionId,LastModified:LastModified}' \
  --output table

# Restore a specific version
aws s3api get-object \
  --bucket "${ORG}-terraform-state-${ENV}" \
  --key "landing-zone/${ENV}/terraform.tfstate" \
  --version-id "<VERSION_ID>" \
  terraform.tfstate.restored

# Upload the restored state
aws s3 cp terraform.tfstate.restored \
  "s3://${ORG}-terraform-state-${ENV}/landing-zone/${ENV}/terraform.tfstate" \
  --sse aws:kms
```

**Step 2 — Force-unlock if DynamoDB lock is stuck**
```bash
terraform force-unlock <LOCK_ID>
```

**Step 3 — Validate state consistency**
```bash
terraform plan -var-file="environments/${ENV}/terraform.tfvars"
# Expect: no changes (state matches live infrastructure)
```

**Step 4 — If state is unrecoverable, import resources**
```bash
# Import Organisation
terraform import module.organization.aws_organizations_organization.main <ORG_ID>

# Import CloudTrail trail
terraform import module.cloudtrail.aws_cloudtrail.org_trail <TRAIL_ARN>

# Import GuardDuty detector
terraform import 'module.guardduty.aws_guardduty_detector.main' <DETECTOR_ID>

# Import Security Hub
terraform import 'module.security_hub.aws_securityhub_account.main' <ACCOUNT_ID>
```

---

## Scenario 3: KMS Key Accidentally Deleted

### Detection
- Config rule `kms-cmk-not-scheduled-for-deletion` non-compliant
- CloudWatch alarm fires: `kms-key-deletion`
- CloudTrail event: `ScheduleKeyDeletion`

### Recovery Procedure

**Step 1 — Cancel key deletion immediately (7–30 day window)**
```bash
# You have time — keys are not deleted immediately
aws kms cancel-key-deletion --key-id <KEY_ID> --region af-south-1
aws kms enable-key --key-id <KEY_ID>
```

**Step 2 — If key is already deleted (past window)**
```bash
# Re-create key via Terraform
terraform apply -target=module.kms -var-file="environments/${ENV}/terraform.tfvars"
```

**Step 3 — Re-encrypt affected resources**
- CloudTrail: update trail to use new KMS ARN
- S3 buckets: update bucket encryption configuration
- CloudWatch Logs: update log group KMS association

**Step 4 — Verify access to encrypted data**
```bash
# Test decryption with new key
aws s3 cp "s3://<CLOUDTRAIL_BUCKET>/AWSLogs/<ACCOUNT>/CloudTrail/<REGION>/<FILE>" /tmp/test.json.gz
gunzip /tmp/test.json.gz && echo "Decryption successful"
```

---

## Scenario 4: GuardDuty / Security Hub Disabled

**Step 1 — Re-enable immediately via Terraform**
```bash
terraform apply \
  -target=module.guardduty \
  -target=module.security_hub \
  -var-file="environments/${ENV}/terraform.tfvars"
```

**Step 2 — Re-enable org-level configuration**
```bash
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
aws guardduty update-organization-configuration \
  --detector-id "${DETECTOR_ID}" \
  --auto-enable
```

**Step 3 — Review findings gap**
- Note the start/end time of the gap
- Manually review CloudTrail logs for the period
- Run AWS Config conformance pack evaluation

---

## DR Testing Schedule

| Test | Frequency | Owner | Last Tested |
|---|---|---|---|
| Full DR activation (tabletop) | Annually | Cloud Architect | — |
| State restore test | Quarterly | Platform Engineering | — |
| Key rotation validation | Monthly | Cloud Security | — |
| Backup restore test | Monthly | Platform Engineering | — |
| Cross-region failover drill | Bi-annually | All teams | — |

---

## Contact & Communication

| Stage | Who | Channel |
|---|---|---|
| DR Declared | Cloud Architect + CISO | Incident bridge + Slack #cloud-incidents |
| Business update (30 min) | Cloud Architect | Leadership email |
| Resolution | All stakeholders | Incident ticket update |
| Post-mortem (48 hrs) | Full team | Confluence + Jira |

---

*Review: Annually and after every DR event | Owner: Platform Engineering*
