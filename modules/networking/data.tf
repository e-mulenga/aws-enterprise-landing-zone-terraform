data "aws_region" "current" {}

# Look up AZs that are actually usable in THIS account/region,
# instead of hardcoding "${region}a" and "${region}b".
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
