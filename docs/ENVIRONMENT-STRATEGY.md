# Environment strategy: one posture, three environments

Dev, test and prod are separate state files and separate identities, but they run the **same configuration**.

## What is shared (`environments/common.tfvars`, committed)

Every control and cost setting: SCPs, CloudTrail, Config, GuardDuty, Security Hub, key strategy, retention, backup, networking cost levers, flow logs, monitoring. A change here reaches all three environments, so a control proven in dev is the control in prod.

## What differs (`environments/<env>/terraform.tfvars`, git-ignored)

| Setting | Why it must differ |
|---|---|
| `environment`, `cost_center` | Naming and tagging |
| Account e-mails and account IDs | AWS requires unique root e-mails |
| `af_south_1`, `eu_west_1` CIDRs | Non-overlapping so VPCs can be peered later (dev 10.10/10.11, test 10.20/10.21, prod 10.30/10.31) |
| `monthly_budget_usd`, alert e-mail | Spend ceiling per environment |
| `route53_domain_name` | Optional per-environment hosted zone |

Nothing else is overridden per environment. If you need a deliberate exception, put it in the environment's tfvars with a comment and an ADR line; reviewers should treat any other override as drift.

## Backend

`environments/<env>/backend.tf` (git-ignored) holds the state bucket. `scripts/tf.sh <env> init` adds the key `landing-zone/<env>/terraform.tfstate`. The same values are echoed in the `terraform_state` output so downstream repositories can configure `terraform_remote_state` without asking.

## Promotion

1. Change `common.tfvars` or a module in a pull request; CI runs format, validate and the security scans.
2. `scripts/tf.sh dev plan`, then `apply`.
3. Same commit: `scripts/tf.sh test plan|apply`, then prod.

Because the inputs are identical, plan differences between environments are limited to identity values.

## Key strategy

One switch (`use_aws_managed_keys`) governs all environments. Flipping it for one environment only is a conscious drift and should be avoided; flip it in `common.tfvars` instead.
