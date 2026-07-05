# ==============================================================================
# dms.tf  (databricks_vpc module)
# DMS wiring only — the replication subnet group that would host a replication
# instance in this VPC's private subnets. No instance by design (the live DMS
# demo already exists in lakeflow_connect/aws); this shows where it would sit
# in a multi-VPC layout.
#
# CreateReplicationSubnetGroup requires the account-level IAM role named
# exactly `dms-vpc-role` to exist first — created (or assumed pre-existing) at
# the root and sequenced via the module-level depends_on in vpcs.tf.
# ==============================================================================

resource "aws_dms_replication_subnet_group" "this" {
  count = var.create_dms_subnet_group ? 1 : 0

  replication_subnet_group_id          = "${local.prefix}-dms"
  replication_subnet_group_description = "Private subnets for DMS replication instances in ${local.prefix}"
  subnet_ids                           = aws_subnet.private[*].id

  tags = merge(var.tags, { Name = "${local.prefix}-dms" })
}
