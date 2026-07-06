# ==============================================================================
# baseline.tf
# ==============================================================================

# Assigns an account-level group as workspace admins. Requires identity
# federation.
resource "databricks_mws_permission_assignment" "workspace_admins" {
  count = var.admin_group_id == null ? 0 : 1

  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = var.admin_group_id
  permissions  = ["ADMIN"]
}

# ------------------------------------------------------------------------------
# Catalog binding stub
#
# databricks_workspace_binding must run against a *workspace-level* provider on
# a metastore-admin workspace.
#
# resource "databricks_workspace_binding" "catalogs" {
#   for_each = toset(var.workspace_catalogs)
#
#   securable_name = each.value
#   workspace_id   = databricks_mws_workspaces.this.workspace_id
# }
# ------------------------------------------------------------------------------
