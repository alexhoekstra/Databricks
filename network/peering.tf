# ==============================================================================
# peering.tf
# The multi-VPC stitching: peering connection per var.peerings entry, routes
# into both sides' private route tables, and the allow-list ingress rules.
# Same account + region, so auto_accept completes the handshake in one apply.
# ==============================================================================

resource "aws_vpc_peering_connection" "this" {
  for_each = var.peerings

  vpc_id      = module.databricks_vpc[each.value.requester].vpc_id
  peer_vpc_id = module.databricks_vpc[each.value.accepter].vpc_id
  auto_accept = true

  tags = { Name = "${var.resource_prefix}-${each.key}" }
}

# Let private-DNS hostnames (e.g. an RDS endpoint in the ingest VPC) resolve
# across the peering from either side.
resource "aws_vpc_peering_connection_options" "this" {
  for_each = var.peerings

  vpc_peering_connection_id = aws_vpc_peering_connection.this[each.key].id

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_route" "peering" {
  for_each = local.peering_routes

  route_table_id            = module.databricks_vpc[each.value.vpc].private_route_table_ids[each.value.rt_index]
  destination_cidr_block    = each.value.dest_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this[each.value.peering_key].id
}

resource "aws_vpc_security_group_ingress_rule" "peering" {
  for_each = local.peering_sg_rules

  security_group_id = each.value.target_sg == "dms" ? module.databricks_vpc[each.value.vpc].dms_security_group_id : module.databricks_vpc[each.value.vpc].security_group_id
  description       = each.value.description
  cidr_ipv4         = each.value.source_cidr
  ip_protocol       = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
}
