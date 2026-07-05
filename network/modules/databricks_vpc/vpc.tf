# ==============================================================================
# vpc.tf  (databricks_vpc module)
# VPC + subnets per the Databricks customer-managed-VPC requirements:
#   - DNS support AND DNS hostnames enabled (hard requirement, also needed for
#     private_dns_enabled interface endpoints)
#   - private subnets in >= 2 AZs, netmask within /17../26 (enforced by the
#     cidr variable validation + newbits = 4 math)
#   - subnets must not be shared between workspaces (enforced cross-entry by
#     workspace_vending/guard.tf on the consuming side)
# Public subnets exist only to host the NAT gateway(s); Databricks clusters
# live in the private subnets.
# ==============================================================================

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = local.prefix })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = local.prefix })
}

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.private_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${local.prefix}-private-${local.azs[count.index]}" })

  lifecycle {
    precondition {
      condition     = var.az_count <= length(data.aws_availability_zones.available.names)
      error_message = "az_count exceeds the availability zones in this region."
    }
  }
}

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${local.prefix}-public-${local.azs[count.index]}" })
}
