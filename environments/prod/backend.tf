terraform {
  backend "s3" {
    bucket     = "REPLACE-ME-acme-terraform-state-prod"
    key        = "landing-zone/prod/terraform.tfstate"
    region     = "af-south-1"
    encrypt    = true
    use_lockfile = true
  }
}
