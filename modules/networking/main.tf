############################################
# Regional VPC wrapper
# Deploys one VPC into whichever region the caller's
# provider points at. Called once per region from the root.
############################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs              = local.azs
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  # NAT Gateway Name tag
  nat_gateway_tags = merge(local.tags, {
    Name = "${local.name}-nat"
  })

  # NAT Elastic IP Name tag
  nat_eip_tags = merge(local.tags, {
    Name = "${local.name}-eip"
  })

  # VPC Name tag
  vpc_tags = merge(local.tags, {
    Name = "${local.name}-vpc"
  })

  # Subnet Name tags
  public_subnet_names = [
    for az in local.azs : "${local.name}-public-${az}"
  ]

  private_subnet_names = [
    for az in local.azs : "${local.name}-private-${az}"
  ]

  database_subnet_names = [
    for az in local.azs : "${local.name}-db-${az}"
  ]

  # One NAT per AZ when single_nat_gateway = false

  create_database_subnet_group = true

  # Managed default security group

  manage_default_security_group = true
  default_security_group_name   = "${local.name}-sg"

  default_security_group_tags = merge(local.tags, {
    Name = "${local.name}-sg"
  })

  default_security_group_ingress = concat(local.public_web_ingress, [
    {
      description = "Allow internal VPC traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = var.vpc_cidr
    },
  ])

  default_security_group_egress = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  tags = local.tags
}

resource "aws_security_group" "main" {
  name        = "${local.name}-sg"
  description = "Primary security group for ${local.name}"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.tags, {
    Name = "${local.name}-sg"
  })
}
