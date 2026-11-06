locals {
  name = "${var.organization_name}-${var.environment}"

  # Approved catalogue: AWS service short name => stable key used in outputs.
  # The key is what downstream repositories index by, so it never changes once
  # published (dots become underscores; events is published as eventbridge).
  endpoint_catalogue = {
    # Tier 1 - first
    sqs            = "sqs"
    sns            = "sns"
    secretsmanager = "secretsmanager"
    logs           = "logs"
    events         = "eventbridge"

    # Tier 2 - later
    kms        = "kms"
    monitoring = "monitoring"
    xray       = "xray"
    "ecr.api"  = "ecr_api"
    "ecr.dkr"  = "ecr_dkr"
    sts        = "sts"
  }

  # Selected services: AWS service short name => output key.
  endpoints = {
    for s in toset(var.interface_endpoints) : s => local.endpoint_catalogue[s]
  }

  # Optional data perimeter: only principals from this AWS Organization may use
  # the endpoint. Not applied to sts (see variable description).
  endpoint_policy = var.endpoint_policy_organization_id == null ? null : jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowOrganizationPrincipalsOnly"
        Effect    = "Allow"
        Principal = "*"
        Action    = "*"
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.endpoint_policy_organization_id
          }
        }
      }
    ]
  })

  # Only the first az_count subnets/AZs get endpoint interfaces.
  endpoint_subnet_ids = slice(var.subnet_ids, 0, min(var.az_count, length(var.subnet_ids)))
  endpoint_azs        = slice(var.availability_zones, 0, min(var.az_count, length(var.availability_zones)))

  tags = merge(var.tags, {
    Environment = var.environment
    Region      = data.aws_region.current.name
    ManagedBy   = "terraform"
  })
}
