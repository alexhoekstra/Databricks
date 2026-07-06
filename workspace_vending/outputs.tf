# ==============================================================================
# outputs.tf 
# Per-workspace vending results, keyed by workspace key.
# ==============================================================================

output "workspaces" {
  description = "Per-workspace vending results, keyed by workspace key."
  value = {
    for name, mod in module.workspace : name => {
      workspace_id             = mod.workspace_id
      workspace_url            = mod.workspace_url
      credentials_id           = mod.credentials_id
      storage_configuration_id = mod.storage_configuration_id
      network_id               = mod.network_id
      cross_account_role_arn   = mod.cross_account_role_arn
      root_bucket              = mod.root_bucket_name
    }
  }
}
