# Service Selection Rationale
## AWS Enterprise Landing Zone

> Comprehensive mapping of every AWS service to its business justification, security rationale, alternatives considered, and Well-Architected Framework alignment.

---

## Service: AWS Organizations

### 1. Why It Was Selected
AWS Organizations is the only AWS-native mechanism that provides: hierarchical account grouping, organisation-level service delegation (one-click GuardDuty admin), and Service Control Policies that constrain even root accounts. It is free and integrates with every AWS security service.

### 2. Problem It Solves
- **Business:** Enables cost consolidation, separate billing boundaries per team or product, and reserved instance sharing across accounts.
- **Technical:** Without Organizations, there is no mechanism to apply guardrails across accounts that teams cannot remove.

### 3. Alternatives Considered
| Alternative | Reason Not Selected |
|---|---|
| Single account with IAM boundaries | No blast-radius isolation; compliance harder to demonstrate |
| Manual account management | No automated guardrails, service delegation, or consolidated billing |
| Third-party MSP account structures | Vendor lock-in; no SCP enforcement |

### 4. Why This Service Was Preferred
- Native, zero-cost, integrates with all security services
- SCPs are the highest enforcement priority in AWS — above even account-root IAM
- Auto-covers new accounts created inside the Organisation

### 5. Well-Architected Alignment
- **Security:** SCPs act as preventive guardrails at the highest level
- **Operational Excellence:** Account factory automates provisioning; new accounts inherit all controls
- **Cost Optimization:** Consolidated billing, reserved instance sharing, volume discounts

### 6. Enterprise Use Case
A financial services firm uses AWS Organizations with SCPs to enforce PCI-DSS data residency — all cardholder data workloads are restricted to approved regions, and no member account can override this constraint regardless of IAM policy.

---

## Service: IAM Identity Center

### 1. Why It Was Selected
IAM Identity Center (formerly AWS SSO) provides SAML 2.0 federation with external IdPs (Azure AD, Okta), centralised permission set management across all accounts, and short-lived temporary credentials — eliminating the need for IAM users and long-lived access keys.

### 2. Problem It Solves
- **Business:** Single sign-on reduces password fatigue and support overhead.
- **Technical:** Eliminates the proliferation of IAM users with long-lived access keys across dozens of accounts.
- **Security:** Offboarding an employee means removing one IdP account — all AWS access is revoked automatically.

### 3. Alternatives Considered
| Alternative | Reason Not Selected |
|---|---|
| Individual IAM users per account | Unmanageable at scale; offboarding risk; no MFA enforcement point |
| Cross-account roles (manual) | Requires individual role trust policies; no federation |
| Third-party PAM (CyberArk, BeyondTrust) | Additional cost and complexity; not needed for AWS-only portfolio |

### 4. Well-Architected Alignment
- **Security:** Short-lived credentials, MFA enforced at identity provider, least-privilege permission sets
- **Operational Excellence:** Permission sets as code; single access management pane

---

## Service: AWS CloudTrail (Organisation Trail)

### 1. Why It Was Selected
A single organisation-level trail captures every API call across all current and future member accounts without any configuration per account. CloudTrail Insights automatically detects anomalous API call rates and error rates using ML baselines.

### 2. Problem It Solves
- **Compliance:** SOC 2, ISO 27001, and PCI-DSS all require complete API audit logs with demonstrated immutability.
- **Investigation:** Without CloudTrail, there is no forensic evidence when a security incident occurs.
- **Operational:** CloudTrail Insights detects infrastructure-level anomalies (runaway automation, credential stuffing) that manual log review would miss.

### 3. Alternatives Considered
| Alternative | Reason Not Selected |
|---|---|
| Per-account trails | Higher cost, management overhead, gaps on new accounts |
| CloudWatch Logs only | No S3 archival, no integrity validation, no global service events |
| Third-party SIEM agents | Require compute in every account, higher cost |

### 4. Benefits

**Security:** Complete audit trail, log file validation (SHA-256 hash chain), KMS encryption  
**Compliance:** 7-year S3 retention + Glacier satisfies most regulatory frameworks  
**Cost:** One organisation trail is more economical than per-account trails  
**Operations:** CloudTrail Insights raises alarms on deviations from normal API call volume

### 5. Well-Architected Alignment
- **Security:** Full API audit trail, CloudTrail Insights for anomaly detection
- **Operational Excellence:** Insights detect infrastructure anomalies; log delivery to CloudWatch enables alarms

---

## Service: Amazon GuardDuty

### 1. Why It Was Selected
GuardDuty provides ML-powered threat detection without agents, infrastructure, or operational overhead. It analyses CloudTrail management events, CloudTrail S3 data events, VPC Flow Logs, DNS query logs, EKS audit logs, and performs malware scanning on EC2 EBS volumes.

### 2. Problem It Solves
Raw CloudTrail logs contain millions of events. GuardDuty's ML models distinguish attacker patterns (credential exfiltration, C2 beaconing, unusual API call sequences) from legitimate operations — surfacing threats that would require a dedicated security analyst team to detect manually.

### 3. Alternatives Considered
| Alternative | Reason Not Selected |
|---|---|
| Manual CloudTrail log review | Impractical at scale; attacker has hours before detection |
| Splunk SIEM | Requires data export, higher cost, complex to maintain |
| Third-party EDR | Requires agent deployment on all EC2 instances |

### 4. Benefits

**Security:** Detects active threats in near-real-time across all data sources  
**Cost:** Pay-per-volume-analysed; no EC2 agent costs  
**Reliability:** Organisation-level auto-enable on new accounts; managed by AWS  
**Operational:** Severity-scored findings with MITRE ATT&CK mapping

### 5. Well-Architected Alignment
- **Security:** Runtime threat detection across CloudTrail, VPC, DNS, S3, EKS, EC2
- **Cost Optimization:** No compute overhead; serverless

---

## Service: AWS Security Hub

### 1. Why It Was Selected
Security Hub aggregates findings from GuardDuty, AWS Config, Inspector, Macie, and Access Analyzer into a single normalised stream using the AWS Security Finding Format (ASFF). It provides compliance posture scores against CIS AWS Foundations v1.4, FSBP, and NIST 800-53.

### 2. Problem It Solves
Security findings across five services in five accounts would require 25 console sessions to review. Security Hub presents a unified score, enables cross-account aggregation, and supports automated remediation via EventBridge rules.

### 3. Alternatives Considered
| Alternative | Reason Not Selected |
|---|---|
| Individual service consoles | Fragmented view; no cross-account aggregation |
| Prisma Cloud / Wiz | Commercial CSPM; adds significant cost; duplicates native coverage |
| Datadog Cloud Security | Requires agent; additional data egress cost |

### 4. Well-Architected Alignment
- **Security:** Consolidated compliance posture; CIS, FSBP, NIST standards
- **Operational Excellence:** Single score drives security roadmap; automated finding routing via EventBridge

---

## Service: AWS Config

### 1. Why It Was Selected
AWS Config records the configuration of every AWS resource and evaluates it against managed rules covering CIS AWS Foundations controls. It provides the configuration history needed for forensic investigation and the compliance evidence needed for audits.

### 2. Problem It Solves
Without Config, there is no answer to "what did this S3 bucket's configuration look like 30 days ago?" Config records every change with a timestamp and actor identity, enabling both root-cause analysis and compliance evidence.

### 3. Managed Rules Deployed (20 rules)
S3 public access, S3 encryption, S3 SSL-only, S3 versioning, CloudTrail enabled, CloudTrail encryption, log file validation, GuardDuty enabled, Security Hub enabled, IAM root key check, MFA on console, IAM user MFA, IAM password policy, IMDSv2, restricted SSH, VPC Flow Logs, KMS not deleted, volume encryption, RDS encryption.

### 4. Well-Architected Alignment
- **Security:** Detective controls; 20 CIS-aligned rules with continuous evaluation
- **Operational Excellence:** Configuration history enables forensic root-cause analysis

---

## Service: AWS KMS (Customer-Managed Keys)

### 1. Why It Was Selected
Four separate CMKs provide cryptographic isolation by service: a compromised CloudTrail key policy does not affect GuardDuty findings decryption. KMS provides automatic annual rotation, CloudTrail key usage auditing, and least-privilege key policies per consumer.

### 2. Problem It Solves
AWS-managed keys (e.g., `aws/s3`) are shared across the account, controlled by AWS, and cannot have customer-defined key policies. CMKs enable deny-decryption conditions (e.g., only CloudTrail service can decrypt) and are required for some compliance frameworks.

### 3. Alternatives Considered
| Alternative | Reason Not Selected |
|---|---|
| AWS managed keys only | No customer key policy control; shared across account |
| AWS CloudHSM | FIPS 140-3 Level 3; required for card data HSM; 10× cost |
| No encryption | Non-negotiable for enterprise production |

### 4. Well-Architected Alignment
- **Security:** Encryption at rest with customer lifecycle control and per-use audit
- **Cost Optimization:** $1/key/month; S3 Bucket Key reduces request cost by up to 99%
- **Sustainability:** KMS reduces cryptographic compute compared to client-side encryption

---

## Service: Service Control Policies (7 Policies)

### 1. Why They Were Selected
SCPs are enforced at the IAM policy evaluation layer, above any member account IAM policy — including the account root. They cannot be bypassed by any principal in a member account.

### 2. Policies and Justifications

| Policy | Business Justification | Technical Control |
|---|---|---|
| DenyPublicS3 | Prevent data breaches from public buckets | Denies PutBucketAcl with public ACL values |
| DenyRootAccountUsage | Root credentials carry unrestricted access | Denies all actions by root principal ARN |
| DenyNonApprovedRegions | Data residency for POPIA/GDPR compliance | Denies non-global service API calls outside approved regions |
| DenyDisableCloudTrail | Preserve audit integrity | Denies DeleteTrail, StopLogging, UpdateTrail |
| DenyDisableSecurityServices | Preserve detective controls | Denies DeleteDetector, DisableSecurityHub, etc. |
| RequireIMDSv2 | Block SSRF credential theft via EC2 metadata | Denies RunInstances where MetadataHttpTokens != required |
| DenyUnencryptedTransit | Protect data in transit | Denies S3/SQS/SNS where aws:SecureTransport = false |

### 3. Well-Architected Alignment
- **Security:** Preventive controls at the highest enforcement level in AWS
- **Governance:** Compliance framework requirements enforced programmatically

---

## Service: AWS Backup

### 1. Why It Was Selected
AWS Backup provides centralised backup management across EC2, RDS, EFS, DynamoDB, and S3 with vault lock (WORM) capability, automated lifecycle to cold storage, and cross-account backup isolation.

### 2. Problem It Solves
Resource-level backup settings (RDS automated backups, EBS snapshots) are account-local and can be deleted by any principal with sufficient IAM permissions. Backup Vault Lock with WORM creates immutable recovery points that cannot be deleted even by the account root.

### 3. Well-Architected Alignment
- **Reliability:** Tested recovery procedures; RTO and RPO defined per tier
- **Security:** Vault lock prevents backup deletion; KMS encryption on all recovery points
- **Cost Optimization:** Cold storage lifecycle reduces long-term retention cost

---

*Document owner: Cloud Security & Platform Engineering | Review: Semi-annually*
