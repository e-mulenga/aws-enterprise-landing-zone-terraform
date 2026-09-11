# ============================================================
# AWS Enterprise Landing Zone — Provider & Version Constraints
# ============================================================
# Portfolio Standard: provider.tf contains BOTH the terraform{}
# block (required_version + required_providers) AND provider
# configurations. No separate versions.tf is used.
# ============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # Remote backend — overridden per environment via backend.tf
  backend "s3" {}
}

# ---- Management Account (default) --------------------------
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-enterprise-landing-zone"
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Environment = var.environment
      Repository  = "aws-enterprise-landing-zone-terraform"
      Portfolio   = "enterprise-cloud-platform"
    }
  }
}

# ---- Security Account (cross-account role assumption) ------
provider "aws" {
  alias  = "security"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.security_account_id}:role/OrganizationAccountAccessRole"
    session_name = "TerraformLandingZone-Security"
  }

  default_tags {
    tags = {
      Project     = "aws-enterprise-landing-zone"
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Environment = var.environment
      Portfolio   = "enterprise-cloud-platform"
    }
  }
}

# ---- Logging Account (cross-account role assumption) -------
provider "aws" {
  alias  = "logging"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.logging_account_id}:role/OrganizationAccountAccessRole"
    session_name = "TerraformLandingZone-Logging"
  }

  default_tags {
    tags = {
      Project     = "aws-enterprise-landing-zone"
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Environment = var.environment
      Portfolio   = "enterprise-cloud-platform"
    }
  }
}
