# Incident Response Runbook
## AWS Enterprise Landing Zone

**Portfolio:** Enterprise Cloud Platform  
**Maintained by:** Cloud Security & Platform Engineering  
**Review cycle:** Quarterly or after any P1 incident  

---

## Severity Definitions

| Severity | Description | Response SLA | Examples |
|---|---|---|---|
| **P1 — Critical** | Production impact, data breach, or active attack | 15 min acknowledge, 1 hr contain | Root account login, mass data exfil, ransomware |
| **P2 — High** | Security control failure or significant misconfig | 30 min, 4 hr resolve | GuardDuty disabled, public S3 bucket, SCP removed |
| **P3 — Medium** | Anomalous activity requiring investigation | 2 hr, 24 hr resolve | Unusual API spike, IAM policy change |
| **P4 — Low** | Policy deviation, non-urgent finding | 24 hr, 5 days resolve | Tagging violations, minor Config rule failure |

---

## Incident Response Process

```
Detect → Triage → Contain → Eradicate → Recover → Post-Incident Review
```

---

## Runbook 1: Unauthorised Root Account Login

**Trigger:** CloudWatch Alarm `root-login` fires; Security Hub CRITICAL finding

### Immediate Actions (0–15 min)

1. **Confirm the alert**
   ```bash
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
     --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
     --region af-south-1 \
     | jq '.Events[] | select(.Username == "root")'
   ```
2. **Immediately revoke all active root sessions**
   - Navigate to IAM → Security credentials → Active sessions → Revoke
3. **Notify the security team** via the P1 escalation channel
4. **Open an incident ticket** with severity P1

### Containment (15–60 min)

5. **Rotate root credentials** — change password, disable/delete access keys
6. **Check for new IAM users or roles created** in the last 2 hours
   ```bash
   aws iam list-users --query 'Users[?CreateDate>=`2024-01-01`]'
   aws iam list-roles --query 'Roles[?CreateDate>=`2024-01-01`]'
   ```
7. **Check for policy changes**
   ```bash
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=EventSource,AttributeValue=iam.amazonaws.com \
     --start-time $(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ)
   ```
8. **Enable MFA on root** if not already active (should be caught by SCP)

### Eradication

9. Delete any suspicious IAM entities created during the window
10. Review and revert any policy changes made during the session
11. Verify all SCPs are intact and correctly attached

### Recovery

12. Enable enhanced monitoring for 72 hours (5-min alarm periods)
13. Require re-authentication for all active SSO sessions

---

## Runbook 2: GuardDuty High-Severity Finding

**Trigger:** SNS alert from `guardduty-alerts` topic; finding severity ≥ 7.0

### Immediate Actions

1. **Retrieve finding details**
   ```bash
   DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
   aws guardduty list-findings \
     --detector-id "${DETECTOR_ID}" \
     --finding-criteria '{"Criterion":{"severity":{"Gte":7},"updatedAt":{"Gte":1}}}' \
     | jq '.'
   ```
2. **Get full finding details**
   ```bash
   FINDING_ID="<id from above>"
   aws guardduty get-findings \
     --detector-id "${DETECTOR_ID}" \
     --finding-ids "${FINDING_ID}" | jq '.Findings[0]'
   ```
3. **Identify affected resource** (EC2 instance, IAM role, S3 bucket)

### Finding-Specific Actions

#### UnauthorizedAccess:IAMUser/ConsoleLoginSuccess.B
```bash
# Disable the IAM user immediately
aws iam update-login-profile --user-name <USERNAME> --password-reset-required
aws iam attach-user-policy --user-name <USERNAME> \
  --policy-arn arn:aws:iam::aws:policy/AWSDenyAll
```

#### Trojan:EC2/BlackholeTraffic / Backdoor:EC2/Spambot
```bash
# Isolate the instance — replace SG with deny-all
aws ec2 create-security-group \
  --group-name "INCIDENT-ISOLATION-$(date +%s)" \
  --description "Incident isolation — no ingress/egress" \
  --vpc-id <VPC_ID>
aws ec2 modify-instance-attribute \
  --instance-id <INSTANCE_ID> \
  --groups <ISOLATION_SG_ID>
# Create forensic snapshot before any remediation
aws ec2 create-snapshot --volume-id <VOLUME_ID> \
  --description "INCIDENT-$(date +%Y%m%d)-forensic"
```

#### Stealth:S3/ServerAccessLoggingDisabled
```bash
aws s3api put-bucket-logging \
  --bucket <BUCKET_NAME> \
  --bucket-logging-status '{"LoggingEnabled":{"TargetBucket":"<LOG_BUCKET>","TargetPrefix":"<BUCKET_NAME>/"}}'
```

---

## Runbook 3: Unexpected SCP Removal or Modification

**Trigger:** CloudWatch Alarm for IAM/Organisation changes; Config rule non-compliance

1. **Identify what changed**
   ```bash
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=EventSource,AttributeValue=organizations.amazonaws.com \
     --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ) \
     | jq '.Events[] | select(.EventName | test("Policy|Attach|Detach"))'
   ```
2. **Re-apply SCPs via Terraform immediately**
   ```bash
   cd environments/prod
   terraform plan -target=module.scp
   terraform apply -target=module.scp -auto-approve
   ```
3. **Review who made the change** (CloudTrail `userIdentity`)
4. **Revoke access** of the principal if not authorised
5. **Add SCPDeleteProtect tag** to policy and raise CAB change to add SCPs to break-glass protection list

---

## Runbook 4: S3 Bucket Made Public

**Trigger:** Config rule `s3-bucket-public-read-prohibited` non-compliant; SCP violation alert

1. **Identify the bucket**
   ```bash
   aws s3control get-public-access-block \
     --account-id <ACCOUNT_ID>
   aws s3api list-buckets --query 'Buckets[*].Name' --output text \
     | tr '\t' '\n' | while read BUCKET; do
       BLOCK=$(aws s3api get-public-access-block --bucket "${BUCKET}" 2>/dev/null || echo '{"PublicAccessBlockConfiguration":{}}')
       echo "${BUCKET}: ${BLOCK}"
     done
   ```
2. **Block public access immediately**
   ```bash
   aws s3api put-public-access-block \
     --bucket <BUCKET_NAME> \
     --public-access-block-configuration \
       BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
   ```
3. **Check access logs for any exfiltration** in the window the bucket was public
4. **Determine what data was exposed** — classify and notify DPO if PII/sensitive
5. **Trigger SCP re-evaluation** to ensure the deny-public-s3 SCP is attached

---

## Post-Incident Review Template

```markdown
## Post-Incident Review — [DATE] [TITLE]

**Severity:** P1 / P2 / P3
**Duration:** Opened [TIME] → Resolved [TIME] (Δ [HH:MM])
**Incident Commander:** [NAME]

### Timeline
| Time (UTC) | Event |
|---|---|
| HH:MM | Alert received |
| HH:MM | Incident declared |
| HH:MM | Containment achieved |
| HH:MM | Root cause identified |
| HH:MM | Resolved |

### Root Cause
[Description]

### Impact
- Services affected:
- Data affected (if any):
- Users impacted:

### What Went Well
1. 
2. 

### What Could Be Improved
1. 
2. 

### Action Items
| Item | Owner | Due Date |
|---|---|---|
| | | |
```

---

## Escalation Contacts

| Role | When to engage |
|---|---|
| Cloud Security Lead | All P1 and P2 |
| CISO | Data breach, regulatory impact |
| Legal/Compliance | Data subject notification required |
| AWS Support (Enterprise) | AWS-side failures, compromised credentials |
| DPO | PII exposure, POPIA/GDPR implications |

---

*Reviewed: Quarterly | Owner: Cloud Security Team*
