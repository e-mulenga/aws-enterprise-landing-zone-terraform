#!/usr/bin/env bash
# ============================================================
# scripts/setup-oidc.sh
# Set up GitHub Actions OIDC trust for Terraform deployment
# ============================================================
# Usage:
#   GITHUB_ORG=your-org GITHUB_REPO=aws-enterprise-landing-zone-terraform \
#   ENV=dev AWS_ACCOUNT_ID=123456789012 bash scripts/setup-oidc.sh
#
# Run this ONCE per environment from a privileged AWS session
# (AdministratorAccess) before the first GitHub Actions run.
# ============================================================

set -euo pipefail

: "${GITHUB_ORG:?Required: GITHUB_ORG}"
: "${GITHUB_REPO:?Required: GITHUB_REPO}"
: "${ENV:?Required: ENV (dev|test|prod)}"
: "${AWS_ACCOUNT_ID:?Required: AWS_ACCOUNT_ID}"
: "${AWS_REGION:=${AWS_DEFAULT_REGION:-af-south-1}}"

OIDC_PROVIDER_URL="https://token.actions.githubusercontent.com"
AUDIENCE="sts.amazonaws.com"
PLAN_ROLE_NAME="GitHubActions-Plan-${ENV}"
APPLY_ROLE_NAME="GitHubActions-Apply-${ENV}"
POLICY_FILE="$(dirname "$0")/../policies/iam/terraform-deployment-role.json"

echo "=========================================="
echo "Setting up OIDC for:"
echo "  GitHub Org/Repo : ${GITHUB_ORG}/${GITHUB_REPO}"
echo "  Environment     : ${ENV}"
echo "  AWS Account     : ${AWS_ACCOUNT_ID}"
echo "  Region          : ${AWS_REGION}"
echo "=========================================="

# ---- 1. Create OIDC Provider (idempotent) -------------------
OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}" &>/dev/null; then
  echo "[✓] OIDC provider already exists."
else
  THUMBPRINT=$(openssl s_client -connect token.actions.githubusercontent.com:443 -servername token.actions.githubusercontent.com \
    </dev/null 2>/dev/null | openssl x509 -fingerprint -noout -sha1 \
    | sed 's/://g' | tr -d '\n' | tail -c 40)
  aws iam create-open-id-connect-provider \
    --url "${OIDC_PROVIDER_URL}" \
    --client-id-list "${AUDIENCE}" \
    --thumbprint-list "${THUMBPRINT}"
  echo "[✓] OIDC provider created."
fi

# ---- 2. Trust policy (branch + environment scoped) ----------
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsOIDCPlan",
      "Effect": "Allow",
      "Principal": { "Federated": "${OIDC_ARN}" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": { "token.actions.githubusercontent.com:aud": "${AUDIENCE}" },
        "StringLike":  { "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*" }
      }
    }
  ]
}
EOF
)

# ---- 3. Plan role (read-only, no apply) ---------------------
if aws iam get-role --role-name "${PLAN_ROLE_NAME}" &>/dev/null; then
  echo "[✓] Plan role already exists: ${PLAN_ROLE_NAME}"
else
  aws iam create-role \
    --role-name "${PLAN_ROLE_NAME}" \
    --assume-role-policy-document "${TRUST_POLICY}" \
    --description "GitHub Actions Terraform plan role for ${ENV}" \
    --tags Key=Environment,Value="${ENV}" Key=ManagedBy,Value=Terraform Key=Repository,Value="${GITHUB_REPO}"
  echo "[✓] Plan role created: ${PLAN_ROLE_NAME}"
fi

# Attach ReadOnly for plan operations
aws iam attach-role-policy \
  --role-name "${PLAN_ROLE_NAME}" \
  --policy-arn "arn:aws:iam::aws:policy/ReadOnlyAccess"

# ---- 4. Apply role (deployment permissions) -----------------
if aws iam get-role --role-name "${APPLY_ROLE_NAME}" &>/dev/null; then
  echo "[✓] Apply role already exists: ${APPLY_ROLE_NAME}"
else
  aws iam create-role \
    --role-name "${APPLY_ROLE_NAME}" \
    --assume-role-policy-document "${TRUST_POLICY}" \
    --description "GitHub Actions Terraform apply role for ${ENV}" \
    --tags Key=Environment,Value="${ENV}" Key=ManagedBy,Value=Terraform Key=Repository,Value="${GITHUB_REPO}"
  echo "[✓] Apply role created: ${APPLY_ROLE_NAME}"
fi

# Create and attach the custom deployment policy
POLICY_NAME="TerraformDeployment-${ENV}"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"

if aws iam get-policy --policy-arn "${POLICY_ARN}" &>/dev/null; then
  # Update existing policy with a new version
  aws iam create-policy-version \
    --policy-arn "${POLICY_ARN}" \
    --policy-document "file://${POLICY_FILE}" \
    --set-as-default
  echo "[✓] Deployment policy updated: ${POLICY_NAME}"
else
  aws iam create-policy \
    --policy-name "${POLICY_NAME}" \
    --policy-document "file://${POLICY_FILE}" \
    --description "Terraform deployment permissions for ${ENV}" \
    --tags Key=Environment,Value="${ENV}" Key=ManagedBy,Value=Terraform
  echo "[✓] Deployment policy created: ${POLICY_NAME}"
fi

aws iam attach-role-policy \
  --role-name "${APPLY_ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}"

echo ""
echo "=========================================="
echo "Next steps — add these to GitHub Secrets:"
echo "  AWS_PLAN_ROLE_ARN_$(echo ${ENV} | tr '[:lower:]' '[:upper:]')  = arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PLAN_ROLE_NAME}"
echo "  AWS_APPLY_ROLE_ARN_$(echo ${ENV} | tr '[:lower:]' '[:upper:]') = arn:aws:iam::${AWS_ACCOUNT_ID}:role/${APPLY_ROLE_NAME}"
echo "=========================================="
