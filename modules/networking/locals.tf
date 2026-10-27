locals {
  name = "${var.organization_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Optional public web ingress on the default SG (kept to match the original code)
  public_web_ingress = var.allow_public_web_ingress ? [
    {
      description = "Allow HTTPS inbound"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      description = "Allow HTTP inbound"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
  ] : []

  tags = merge(var.tags, {
    Environment = var.environment
    Region      = data.aws_region.current.name
    ManagedBy   = "terraform"
  })
}
