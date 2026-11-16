# ============================================================
# Module: github-oidc - Passwordless CI/CD for GitHub Actions
# ============================================================
# One GitHub OIDC provider is allowed per AWS account. If it was already
# created (for example by scripts/setup-oidc.sh) leave create_provider = false
# and it is simply looked up and exported. Set it to true only on a fresh account.
#
# Optional roles: each role is trusted only for the exact GitHub subjects
# listed (repository + branch / environment), never for "*".
# ============================================================

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_provider ? 0 : 1

  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # GitHub's published root CA thumbprints. AWS now validates the chain with its
  # trusted CA library, but older provider versions still require the argument.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = { Name = "${var.organization_name}-${var.environment}-github-oidc" }

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  # Per-repository roles are expanded into the same shape as var.roles. Subjects are exact:
  # one per branch, per environment and (optionally) pull requests of that repository.
  repository_roles = {
    for key, r in var.repositories : key => {
      description = "GitHub Actions role for ${r.repository}"
      subjects = concat(
        [for b in r.branches : "repo:${r.repository}:ref:refs/heads/${b}"],
        [for e in r.environments : "repo:${r.repository}:environment:${e}"],
        r.allow_pull_requests ? ["repo:${r.repository}:pull_request"] : []
      )
      policy_arns          = r.policy_arns
      max_session_duration = r.max_session_duration
    }
  }

  all_roles = merge(var.roles, local.repository_roles)

  provider_arn = one(concat(
    data.aws_iam_openid_connect_provider.github[*].arn,
    aws_iam_openid_connect_provider.github[*].arn,
  ))

  role_policy_attachments = merge([
    for role_name, role in local.all_roles : {
      for arn in role.policy_arns : "${role_name}|${arn}" => {
        role       = role_name
        policy_arn = arn
      }
    }
  ]...)
}

data "aws_iam_policy_document" "trust" {
  for_each = local.all_roles

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = each.value.subjects
    }
  }
}

resource "aws_iam_role" "github" {
  for_each = local.all_roles

  name                 = "${var.organization_name}-${var.environment}-gha-${each.key}"
  description          = each.value.description
  assume_role_policy   = data.aws_iam_policy_document.trust[each.key].json
  max_session_duration = each.value.max_session_duration

  tags = { Name = "${var.organization_name}-${var.environment}-gha-${each.key}" }
}

resource "aws_iam_role_policy_attachment" "github" {
  for_each = local.role_policy_attachments

  role       = aws_iam_role.github[each.value.role].name
  policy_arn = each.value.policy_arn
}
