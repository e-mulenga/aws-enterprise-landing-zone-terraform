terraform {
  backend "s3" {
    bucket     = "REPLACE-ME-org-terraform-state-test"
    key        = "landing-zone/test/terraform.tfstate"
    region     = "af-south-1"
    encrypt    = true
    use_lockfile = true
  }
}
