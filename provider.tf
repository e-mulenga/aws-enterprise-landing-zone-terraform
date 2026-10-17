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

# ---- Networking module --------------------------

# Provider aliases are static: Terraform cannot create providers with
# for_each/count, so each region gets its own block.
provider "aws" {
  alias  = "af_south_1"
  region = "af-south-1"

  default_tags {
    tags = {
      Project = var.organization_name
    }
  }
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"

  default_tags {
    tags = {
      Project = var.organization_name
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
