# ==============================================================================
# endpoints.tf
# The standard Databricks endpoint trio, so cluster traffic to S3/STS/Kinesis
# stays on the AWS backbone instead of transiting the NAT gateway:
#   - S3: gateway endpoint, attached to every private route table (free)
#   - STS + Kinesis: interface endpoints in the private subnets with
#     private_dns_enabled, fronted by the endpoints SG
# Kinesis must be the `kinesis-streams` service (Databricks uses Kinesis
# streams for internal logging) — not plain `kinesis`.
# ==============================================================================

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_databricks_endpoints ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = merge(var.tags, { Name = "${local.prefix}-s3" })
}

resource "aws_vpc_endpoint" "sts" {
  count = var.enable_databricks_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${local.region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${local.prefix}-sts" })
}

resource "aws_vpc_endpoint" "kinesis" {
  count = var.enable_databricks_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${local.region}.kinesis-streams"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${local.prefix}-kinesis" })
}

# ------------------------------------------------------------------------------
# Back-end PrivateLink (stretch) — documented stub, intentionally not live.
#
# Full private connectivity to the Databricks control plane adds two more
# interface endpoints pointed at Databricks-published endpoint services (the
# regional vpce-svc-* ids live in the Databricks PrivateLink docs):
#
# resource "aws_vpc_endpoint" "databricks_rest_api" {
#   vpc_id              = aws_vpc.this.id
#   service_name        = "com.databricks.<region>.<vpce-svc id: workspace/REST API>"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.endpoints[0].id]
#   private_dns_enabled = false  # enable only after registration
# }
#
# resource "aws_vpc_endpoint" "databricks_scc_relay" {
#   vpc_id              = aws_vpc.this.id
#   service_name        = "com.databricks.<region>.<vpce-svc id: SCC relay>"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.endpoints[0].id]
#   private_dns_enabled = false
# }
#
# Each then gets registered at the account level:
# databricks_mws_vpc_endpoint x2, referenced from databricks_mws_networks'
# vpc_endpoints { rest_api = [...], dataplane_relay = [...] }, plus a
# databricks_mws_private_access_settings attached to the workspace.
# ------------------------------------------------------------------------------
