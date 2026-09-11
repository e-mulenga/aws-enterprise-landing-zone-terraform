# Contributing Guide
## AWS Enterprise Landing Zone

Thank you for contributing to this repository. Please read this guide before opening a pull request.

---

## Portfolio Context

This repository is **position 1** in the Enterprise Cloud Platform Portfolio. Changes here cascade downstream to:
- `terraform-enterprise-module-library` (consumes outputs)
- `aws-devsecops-pipeline` (depends on IAM Identity Center)
- All other portfolio repositories

**Breaking changes require CAB approval before merging to `main`.**

---

## Branch Strategy

```
main          ← production-only, protected
develop       ← integration branch
feature/*     ← new features
fix/*         ← bug fixes
hotfix/*      ← urgent production fixes (require P1 incident reference)
```

---

## Pull Request Requirements

All PRs must:

- [ ] Pass all GitHub Actions checks (tfsec, checkov, trivy, TFLint, gitleaks)
- [ ] Include `terraform plan` output for affected environments
- [ ] Update `README.md` if new resources or variables are added
- [ ] Follow the naming convention: `<org>-<env>-<service>-<resource>`
- [ ] Not hardcode account IDs, emails, regions, or secrets
- [ ] Add or update variable descriptions in `variables.tf`
- [ ] Reference a Jira/GitHub issue in the PR description
- [ ] Be reviewed by at least **two** engineers (one must be from the security team for changes to `modules/scp`, `modules/iam-identity-center`, or `policies/`)

---

## Terraform Standards

- Use `provider.tf` — **no** `versions.tf`
- Pin provider versions with `~>` (minor version flexibility)
- All configurable values must be variables — no literals in `main.tf`
- Use `lifecycle { prevent_destroy = true }` on all account resources
- Every module must have `main.tf`, `variables.tf`, and `outputs.tf`
- Use `for_each` over `count` for named resources
- Mark sensitive outputs with `sensitive = true`
- Run `terraform fmt -recursive` before committing

---

## Commit Message Format

```
<type>(<scope>): <short description>

Types: feat | fix | security | docs | refactor | test | ci
Scopes: org | accounts | kms | cloudtrail | guardduty | sechub | scp | config | monitoring | backup | iam

Examples:
feat(guardduty): add malware protection data source
security(scp): add IMDSv2 enforcement policy
fix(kms): correct CloudTrail key policy condition
docs(readme): update portfolio diagram
```

---

## Testing

Before opening a PR:

```bash
# Format check
terraform fmt -check -recursive

# Validate (no backend required)
terraform init -backend=false && terraform validate

# Security scan
tfsec . --minimum-severity HIGH
checkov -d . --framework terraform

# Lint
tflint --recursive

# Secret scan
gitleaks detect --source . --verbose
```

---

## Sensitive Information

**Never commit:**
- AWS account IDs
- Email addresses
- Passwords, API keys, or tokens
- Real `terraform.tfvars` files
- `.terraform/` directories or `*.tfstate` files
