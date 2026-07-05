# ==============================================================================
# locals.tf  (databricks_vpc module)
# AZ selection + subnet math. newbits = 4 splits the VPC into 16 equal slots
# (e.g. /20 -> /24s): slots 0..az_count-1 are private, 8..8+az_count-1 public.
# ==============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

locals {
  prefix = "${var.resource_prefix}-${var.name}"

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  private_cidrs = [for i in range(var.az_count) : cidrsubnet(var.cidr, 4, i)]
  public_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.cidr, 4, 8 + i)]

  nat_count = var.nat_per_az ? var.az_count : 1

  region = data.aws_region.current.region
}
