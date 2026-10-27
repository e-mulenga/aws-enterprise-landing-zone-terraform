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

  # Dev cost control: the NAT Gateway is the largest fixed cost in this stack.
  enable_nat_gateway     = var.enable_nat_gateway
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

# ---- Gateway endpoints (free) -------------------------------
# S3 (and optionally DynamoDB) gateway endpoints cost nothing, keep S3 traffic
# off the NAT Gateway (less data-processing charge) and off the internet.
resource "aws_vpc_endpoint" "gateway" {
  for_each = toset(var.gateway_endpoints)

  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type = "Gateway"

  route_table_ids = distinct(concat(
    module.vpc.private_route_table_ids,
    module.vpc.database_route_table_ids,
    module.vpc.public_route_table_ids,
  ))

  tags = merge(local.tags, {
    Name = "${local.name}-${each.key}-gateway-endpoint"
  })
}

# ---- Interface endpoints (optional, billed hourly per AZ) -----
# Off by default. Each endpoint is roughly USD 7-8 per AZ per month, so two
# AZs is about USD 15/month per service. See docs/cost-analysis.md.
resource "aws_security_group" "endpoints" {
  count = length(var.interface_endpoints) > 0 ? 1 : 0

  name        = "${local.name}-vpce-sg"
  description = "HTTPS from inside the VPC to interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.tags, {
    Name = "${local.name}-vpce-sg"
  })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_endpoints)

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.tags, {
    Name = "${local.name}-${each.key}-endpoint"
  })
}
