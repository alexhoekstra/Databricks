# ==============================================================================
# workspaces.tf
# One modules/workspace instance per entry in var.workspaces.
# ==============================================================================

module "workspace" {
  for_each = var.workspaces
  source   = "./modules/workspace"

  providers = {
    databricks = databricks.account
    aws        = aws
  }

  workspace_key         = each.key
  workspace_name        = local.workspaces_effective[each.key].workspace_name
  databricks_account_id = var.databricks_account_id
  region                = local.workspaces_effective[each.key].region
  resource_prefix       = var.resource_prefix

  root_bucket_name          = local.workspaces_effective[each.key].root_bucket_name
  force_destroy_root_bucket = var.force_destroy_root_buckets

  deployment_name = each.value.deployment_name
  pricing_tier    = each.value.pricing_tier
  custom_tags     = each.value.custom_tags

  network = each.value.network

  admin_group_id     = local.workspaces_effective[each.key].admin_group_id
  workspace_catalogs = each.value.workspace_catalogs
}
