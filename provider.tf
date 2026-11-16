# ============================================================
# AWS Enterprise Landing Zone — Provider & Version Constraints
# ============================================================
# Portfolio Standard: provider.tf contains BOTH the terraform{}
# Provider aliases are static: Terraform cannot create providers with
# for_each / count, so every Region the landing zone touches has its own block.
#
#   aws             primary Region (var.aws_region, af-south-1)
#   aws.af_south_1  primary Region, explicit (networking)
#   aws.eu_west_1   disaster recovery Region (networking, backup DR vault, AI)
#   aws.us_east_1   global services (ACM certificates for CloudFront)
#   aws.logging     Region that holds the central log buckets (var.logging_region)
#   aws.security    reserved for the Security account once member accounts exist
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
      Environment = var.environment
      Project     = "aws-enterprise-landing-zone"
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Repository  = "aws-enterprise-landing-zone-terraform"
    }
  }
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "aws-enterprise-landing-zone"
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Repository  = "aws-enterprise-landing-zone-terraform"
    }
  }
}

# ---- us-east-1: global-service endpoints (CloudFront certificates, CUR, alarms on global events) ----
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "aws-enterprise-landing-zone"
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Repository  = "aws-enterprise-landing-zone-terraform"
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
