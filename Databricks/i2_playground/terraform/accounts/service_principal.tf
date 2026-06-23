#service_principal.tf

data "databricks_group" "admins" {
  display_name = "admins"
}

resource "databricks_service_principal" "admin_sp" {
  display_name = "Admin SP"
}

resource "databricks_group_member" "sp_admin_membership" {
  group_id  = data.databricks_group.admins.id
  member_id = databricks_service_principal.admin_sp.id
}

resource "databricks_git_credential" "sp_git_credential" {
  git_provider          = "gitHub"
  git_username          = "Alex's Databricks Admin SP"
  personal_access_token = sensitive(data.vault_kv_secret_v2.databricks_secrets.data["GITHUB_ADMIN_PAT"])
  principal_id          = databricks_service_principal.admin_sp.id
}

# create a secret for the sp, the secret can be used to request OAuth tokens for the service principal
resource "databricks_service_principal_secret" "admin_sp_secret" {
  service_principal_id = databricks_service_principal.admin_sp.id
}

locals {
  # Safely read existing keys — falls back to empty map if secret doesn't exist yet
  existing_secrets = try(data.vault_kv_secret_v2.databricks_secrets.data, {})

  # Merge: existing keys are preserved, new SP keys are added/updated
  merged_secrets = merge(local.existing_secrets, {
    DATABRICKS_CLIENT_ID     = databricks_service_principal.admin_sp.application_id
    DATABRICKS_CLIENT_SECRET = databricks_service_principal_secret.admin_sp_secret.secret
  })
}

# Store the merged secret back into Vault
resource "vault_kv_secret_v2" "admin_sp_secret" {
  mount     = "kv"
  name      = "databricks"
  data_json = jsonencode(local.merged_secrets)
}