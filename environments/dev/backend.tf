terraform {
  backend "s3" {
    bucket     = "REPLACE-ME-org-terraform-state-dev"
    key        = "landing-zone/dev/terraform.tfstate"
    region     = "af-south-1"
    encrypt    = true
    use_lockfile = true
  }
}
