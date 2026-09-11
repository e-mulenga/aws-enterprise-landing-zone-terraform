# Security Policy
## AWS Enterprise Landing Zone

## Reporting a Vulnerability

If you discover a security vulnerability in this repository — including a misconfiguration, exposed secret, or insecure default — please **do not** open a public GitHub issue.

Report privately via:
- **Email:** security@[your-org].com
- **Subject:** `[SECURITY] aws-enterprise-landing-zone — <brief description>`

Include:
1. Description of the vulnerability
2. Steps to reproduce
3. Potential impact
4. Suggested remediation (optional)

We aim to acknowledge reports within **48 hours** and provide a resolution timeline within **5 business days**.

---

## Security Controls in This Repository

| Control | Implementation |
|---|---|
| No secrets in code | `.gitignore` blocks `*.tfvars`, `*.tfstate`, `.aws/`, keys |
| No hardcoded IDs | All account IDs, regions, emails are variables |
| OIDC authentication | GitHub Actions uses OIDC — no long-lived AWS keys |
| Encrypted state | S3 backend uses KMS encryption + versioning |
| Mandatory code review | Branch protection requires 2 approvals for `main` |
| Static analysis | tfsec + checkov + trivy + gitleaks on every PR |
| Least-privilege CI/CD | OIDC role scoped to minimum required actions |

---

## Supported Versions

| Branch | Security Fixes |
|---|---|
| `main` | ✅ Yes |
| `develop` | ✅ Yes |
| Older feature branches | ❌ No — merge to develop first |
