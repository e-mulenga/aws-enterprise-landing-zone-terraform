terraform {
  backend "s3" {
    bucket         = "REPLACE-ME-org-terraform-state-dev"
    key            = "landing-zone/dev/terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key"
    dynamodb_table = "REPLACE-ME-terraform-state-lock-dev"
  }
}
