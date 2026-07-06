# ==============================================================================
# vpcs.tf
# One modules/databricks_vpc instance per entry in var.vpcs
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
  depends_on = [time_sleep.dms_vpc_propagation]
}
