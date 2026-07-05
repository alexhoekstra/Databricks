# ==============================================================================
# vpcs.tf  (network root)
# One modules/databricks_vpc instance per entry in var.vpcs — the same
# config-driven pattern as workspace_vending's workspaces map. Peering between
# instances is stitched at the root (peering.tf): it's inherently
# cross-instance, so the module stays peer-agnostic.
# ==============================================================================

module "databricks_vpc" {
  for_each = var.vpcs
  source   = "./modules/databricks_vpc"

  name                        = each.key
  resource_prefix             = var.resource_prefix
  cidr                        = each.value.cidr
  az_count                    = each.value.az_count
  enable_databricks_endpoints = each.value.enable_databricks_endpoints
  create_dms_subnet_group     = each.value.create_dms_subnet_group
  nat_per_az                  = each.value.nat_per_az
  tags                        = each.value.tags

  # DMS subnet groups need the account-level dms-vpc-role first. Module-wide
  # depends_on is coarse, but the wait is 15s and runs once, in parallel.
  depends_on = [time_sleep.dms_vpc_propagation]
}
