# ==============================================================================
# security.tf
# Three security groups:
#   - workspace: the SG exported in security_group_ids — carries the documented
#     Databricks customer-managed-VPC rules
#   - endpoints: fronts the interface endpoints (443 from the VPC CIDR) so the
#     exported workspace SG never needs mutating
#   - dms: created with the DMS subnet group; carries no static ingress — the
#     root's peering `allow` rules land here
# ==============================================================================

resource "aws_security_group" "workspace" {
  name        = "${local.prefix}-databricks"
  description = "Databricks workspace security group (customer-managed VPC rules)"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${local.prefix}-databricks" })
}

# --- ingress: cluster-internal only ------------------------------------------
# Databricks requires all-TCP + all-UDP from the workspace SG to itself
# (inter-node communication). Nothing else enters.

resource "aws_vpc_security_group_ingress_rule" "self_tcp" {
  security_group_id            = aws_security_group.workspace.id
  description                  = "Databricks inter-node (all TCP from this SG)"
  referenced_security_group_id = aws_security_group.workspace.id
  ip_protocol                  = "tcp"
  from_port                    = 0
  to_port                      = 65535
}

resource "aws_vpc_security_group_ingress_rule" "self_udp" {
  security_group_id            = aws_security_group.workspace.id
  description                  = "Databricks inter-node (all UDP from this SG)"
  referenced_security_group_id = aws_security_group.workspace.id
  ip_protocol                  = "udp"
  from_port                    = 0
  to_port                      = 65535
}

# --- egress: the documented Databricks port list ------------------------------

resource "aws_vpc_security_group_egress_rule" "self_tcp" {
  security_group_id            = aws_security_group.workspace.id
  description                  = "Databricks inter-node (all TCP to this SG)"
  referenced_security_group_id = aws_security_group.workspace.id
  ip_protocol                  = "tcp"
  from_port                    = 0
  to_port                      = 65535
}

resource "aws_vpc_security_group_egress_rule" "self_udp" {
  security_group_id            = aws_security_group.workspace.id
  description                  = "Databricks inter-node (all UDP to this SG)"
  referenced_security_group_id = aws_security_group.workspace.id
  ip_protocol                  = "udp"
  from_port                    = 0
  to_port                      = 65535
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.workspace.id
  description       = "Databricks control plane + S3/STS/Kinesis (via endpoints) + library repos"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "metastore" {
  security_group_id = aws_security_group.workspace.id
  description       = "Legacy Hive metastore (MySQL)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 3306
  to_port           = 3306
}

resource "aws_vpc_security_group_egress_rule" "scc_relay" {
  security_group_id = aws_security_group.workspace.id
  description       = "Secure cluster connectivity relay (also used by back-end PrivateLink)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 6666
  to_port           = 6666
}

resource "aws_vpc_security_group_egress_rule" "internal_services" {
  security_group_id = aws_security_group.workspace.id
  description       = "Databricks internal services / future extendability"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 8443
  to_port           = 8451
}

# tcp 2443 is required only with the compliance security profile (FIPS
# endpoints) — intentionally omitted here:
# resource "aws_vpc_security_group_egress_rule" "fips" {
#   security_group_id = aws_security_group.workspace.id
#   description       = "Compliance security profile (FIPS) endpoints"
#   cidr_ipv4         = "0.0.0.0/0"
#   ip_protocol       = "tcp"
#   from_port         = 2443
#   to_port           = 2443
# }

# --- interface-endpoint SG ----------------------------------------------------

resource "aws_security_group" "endpoints" {
  count = var.enable_databricks_endpoints ? 1 : 0

  name        = "${local.prefix}-endpoints"
  description = "Interface VPC endpoints (443 from inside the VPC)"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${local.prefix}-endpoints" })
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  count = var.enable_databricks_endpoints ? 1 : 0

  security_group_id = aws_security_group.endpoints[0].id
  description       = "HTTPS to the endpoint ENIs from anywhere in the VPC"
  cidr_ipv4         = var.cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# --- DMS SG (wiring only) -----------------------------------------------------

resource "aws_security_group" "dms" {
  count = var.create_dms_subnet_group ? 1 : 0

  name        = "${local.prefix}-dms"
  description = "DMS replication instances (ingress arrives via root-level peering allow rules)"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${local.prefix}-dms" })
}

resource "aws_vpc_security_group_egress_rule" "dms_all" {
  count = var.create_dms_subnet_group ? 1 : 0

  security_group_id = aws_security_group.dms[0].id
  description       = "DMS reaches sources/targets + AWS service APIs via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
