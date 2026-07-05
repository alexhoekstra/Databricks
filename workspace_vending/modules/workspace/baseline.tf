# ==============================================================================
# baseline.tf  (workspace module)
# Per-workspace baseline applied right after creation: admin group binding,
# plus the catalog-binding stub.
# ==============================================================================

# Assigns an account-level group as workspace admins. Requires identity
# federation (default on current UC-enabled accounts).
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
# a metastore-admin workspace, and Terraform cannot wire a distinct provider
# per for_each module instance. On a paid account you'd apply these bindings
# from a small follow-up root (or the governance/ root) pointed at the admin
# workspace, consuming this module's workspace_id output + var.workspace_catalogs.
#
# resource "databricks_workspace_binding" "catalogs" {
#   for_each = toset(var.workspace_catalogs)
#
#   securable_name = each.value
#   workspace_id   = databricks_mws_workspaces.this.workspace_id
# }
# ------------------------------------------------------------------------------
