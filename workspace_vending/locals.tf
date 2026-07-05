# ==============================================================================
# locals.tf
# Per-workspace effective config: defaults coalesced once, so guard.tf and the
# module call read the same resolved values.
# ==============================================================================

locals {
  workspaces_effective = {
    for key, ws in var.workspaces : key => {
      workspace_name   = coalesce(ws.workspace_name, key)
      region           = coalesce(ws.region, var.aws_region)
      root_bucket_name = coalesce(ws.root_bucket_name, "${var.resource_prefix}-${key}-root")
      admin_group_id   = ws.admin_group_id != null ? ws.admin_group_id : var.admin_group_id
    }
  }
}
