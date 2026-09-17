terraform {
  required_version = ">= 1.9.0"

  backend "s3" {
    bucket     = "REPLACE-ME-org-terraform-state-dev"
    key        = "landing-zone/prod/terraform.tfstate"  # Path inside the bucket
    region     = "af-south-1"
    encrypt    = true   # Ensures server-side encryption
    use_lockfile = true # Enables native S3 state locking (replaces DynamoDB)
  }
}
