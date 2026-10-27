# ============================================================
# Module: organization - AWS Organizations (existing organisation)
# ============================================================
# The organisation itself already exists and is only READ here
# (data.aws_organizations_organization.main). Creating it again would fail.
#
# The OU layout below matches what is already deployed and recorded in the
# Terraform state, so a plan makes NO changes to it:
#
#   Root
#   |- Security
#   |- Infrastructure
#   |- Audit
#   |- Sandbox
#   |- Workloads
#       |- Development   (resource name: workloads_dev)
#       |- Production    (resource name: workloads_prod)
#
# prevent_destroy protects every OU: they are shared governance
# structure that other repositories and SCPs attach to.
# ============================================================

locals {
  root_id = data.aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = local.root_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = local.root_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "audit" {
  name      = "Audit"
  parent_id = local.root_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = local.root_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = local.root_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "workloads_dev" {
  name      = "Development"
  parent_id = aws_organizations_organizational_unit.workloads.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "workloads_prod" {
  name      = "Production"
  parent_id = aws_organizations_organizational_unit.workloads.id

  lifecycle {
    prevent_destroy = true
  }
}
