# ==============================================================================
# dms.tf
# DMS wiring only 
#
# ==============================================================================

resource "aws_dms_replication_subnet_group" "this" {
  count = var.create_dms_subnet_group ? 1 : 0

  replication_subnet_group_id          = "${local.prefix}-dms"
  replication_subnet_group_description = "Private subnets for DMS replication instances in ${local.prefix}"
  subnet_ids                           = aws_subnet.private[*].id

  tags = merge(var.tags, { Name = "${local.prefix}-dms" })
}
