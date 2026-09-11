terraform {
  backend "s3" {
    bucket         = "REPLACE-ME-acme-terraform-state-prod"
    key            = "landing-zone/prod/terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key"
    dynamodb_table = "REPLACE-ME-terraform-state-lock-prod"
  }
}
