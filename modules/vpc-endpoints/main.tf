############################################
# Interface VPC Endpoints (AWS PrivateLink)
# Deploys one shared endpoint security group and one Interface endpoint per
# approved AWS service into whichever region the caller's provider points at.
# Called once per region from the root, like modules/vpc-flow-logs.
#
# Why a separate module: networking owns the VPC; this module owns private
# service connectivity. Other repositories consume the outputs through
# terraform_remote_state and never create their own endpoints, so private DNS
# (one endpoint per service per VPC) is never contested.
############################################

data "aws_region" "current" {}

# Private DNS needs both DNS attributes on the VPC.
data "aws_vpc" "this" {
  id = var.vpc_id
}

# Fail at plan time, not apply time, if a service is not offered in this
# Region (or not in one of our AZs). Interface endpoint availability differs
# by Region, so this is checked rather than assumed, especially for af-south-1.
data "aws_vpc_endpoint_service" "this" {
  for_each = local.endpoints

  service_name = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  service_type = "Interface"
}

# ---- Shared security group ----------------------------------
# One security group for all endpoints. Inbound HTTPS from the VPC only.
# No egress rules: Terraform removes the default allow-all egress, and an
# endpoint network interface only ever answers inbound connections (stateful).
resource "aws_security_group" "interface_endpoints" {
  name_prefix = "${local.name}-vpce-"
  description = "HTTPS from inside the VPC to Interface VPC endpoints (PrivateLink)"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC resources"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = concat([var.vpc_cidr], var.additional_ingress_cidr_blocks)
  }

  tags = merge(local.tags, {
    Name = "${local.name}-vpce-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ---- Interface endpoints ------------------------------------
resource "aws_vpc_endpoint" "interface" {
  for_each = local.endpoints

  vpc_id              = var.vpc_id
  service_name        = data.aws_vpc_endpoint_service.this[each.key].service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.interface_endpoints.id]
  private_dns_enabled = true
  policy              = each.key == "sts" ? null : local.endpoint_policy

  tags = merge(local.tags, {
    Name = "${local.name}-${each.key}-endpoint"
  })

  lifecycle {
    precondition {
      condition     = data.aws_vpc.this.enable_dns_support && data.aws_vpc.this.enable_dns_hostnames
      error_message = "Private DNS for Interface endpoints needs enable_dns_support and enable_dns_hostnames on the VPC."
    }

    precondition {
      condition = alltrue([
        for az in var.availability_zones :
        contains(data.aws_vpc_endpoint_service.this[each.key].availability_zones, az)
      ])
      error_message = "The ${each.key} endpoint service is not offered in every Availability Zone of the endpoint subnets in this Region."
    }
  }
}
