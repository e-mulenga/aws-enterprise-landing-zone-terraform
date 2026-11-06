locals {
  name = "${var.organization_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)


  tags = merge(var.tags, {
    Environment = var.environment
    Region      = data.aws_region.current.name
    ManagedBy   = "terraform"
  })
}
