# ============================================================
# Module: ecr - Shared container registries
# ============================================================
# Cost posture: ECR bills for storage only (about USD 0.10 per GB-month), so
# the lifecycle policy deletes untagged images after 7 days and keeps the most
# recent tagged images. Basic scan-on-push is free. Enhanced scanning (Amazon
# Inspector) is deliberately NOT enabled.
# ============================================================

locals {
  names = toset(var.repositories)
}

resource "aws_ecr_repository" "shared" {
  for_each = local.names

  name                 = "${var.organization_name}-${var.environment}/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = var.kms_key_arn == null ? "AES256" : "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = { Name = "${var.organization_name}-${var.environment}-${each.key}" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_lifecycle_policy" "shared" {
  for_each = aws_ecr_repository.shared

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the most recent ${var.keep_last_images} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_last_images
        }
        action = { type = "expire" }
      }
    ]
  })
}

# Optional: let other accounts in the organisation pull the shared images.
data "aws_iam_policy_document" "org_pull" {
  count = var.organization_id == "" ? 0 : 1

  statement {
    sid    = "AllowOrganisationPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [var.organization_id]
    }
  }
}

resource "aws_ecr_repository_policy" "org_pull" {
  for_each = var.organization_id == "" ? {} : aws_ecr_repository.shared

  repository = each.value.name
  policy     = data.aws_iam_policy_document.org_pull[0].json
}
