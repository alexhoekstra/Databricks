# ==============================================================================
# vpc.tf
# VPC + subnets per the Databricks customer-managed-VPC requirements:
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
