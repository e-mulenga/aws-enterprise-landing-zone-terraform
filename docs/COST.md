# Cost controls

The stack is built to stay cheap by default. Everything that bills per hour is off until a workload needs it, and the same settings apply to dev, test and prod.

| Area | Default | Change it when |
|---|---|---|
| NAT Gateway | off (`enable_nat_gateway_*`) | A private workload needs internet egress |
| Interface endpoints | off; 1 AZ when on (`interface_endpoint_az_count`) | A workload needs private service access; use 2 AZs only for AZ-local resilience |
| Gateway endpoints | S3 + DynamoDB (free) | Never remove: they keep S3 traffic off NAT |
| Encryption | AWS managed keys | Governance requires CMKs (USD 1/key/month, 5 keys per environment, more with DR replicas) |
| State | SSE-S3 + native lockfile | N/A (no DynamoDB, no state CMK) |
| AWS Config | DAILY recording, `core` rules | Continuous recording is needed for a specific audit |
| CloudTrail | one org trail; data events and Insights off | Data-event auditing is required for named buckets |
| Security Hub | FSBP | Add CIS only if a standard demands it |
| GuardDuty | foundational | Enable protection plans per workload |
| Flow logs | REJECT only, S3 | Investigating accepted traffic |
| Log archives | `log_archive_expiry_days` = 730, access logs 90 days | A regulation requires longer retention |
| Anomaly detection | on (free) | Never turn off |
| Budgets | per environment | Adjust `monthly_budget_usd` |

Interface endpoints cost per endpoint per AZ per hour plus per GB; with the default tier-1 list this is the first place spend appears when enabled, so enable them service by service.
