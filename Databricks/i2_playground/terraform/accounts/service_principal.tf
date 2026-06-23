#service_principal.tf

data "databricks_group" "admins" {
  display_name = "admins"
}

# create the service principal
resource "databricks_service_principal" "admin_sp" {
  display_name = "Admin SP"
}
# add it to the admins group
resource "databricks_group_member" "sp_admin_membership" {
  group_id  = data.databricks_group.admins.id
  member_id = databricks_service_principal.admin_sp.id
}

# Use the Personal Access Token (PAT) from Vault to create a Git credential for the service principal
# This was manually created and loaded into vault but it looks like there is a way to use the github provider 
# to create a PAT and load it into vault. I created a fine grained PAT for this to use, which doesn't
# appear to be supported, just the classic PATs. I will look into this more later, but for now, this is a manual step.
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

# this is relying on the fact that privs on unity catalogs are inherited
# you would want to restrict this much further in a real use case
resource "databricks_grants" "main_catalog" {
  catalog = "main"

  grant {
    principal  = databricks_service_principal.admin_sp.application_id #application ID since it uses OAUTH
    privileges = ["USE CATALOG", "USE SCHEMA", "CREATE SCHEMA", "CREATE TABLE", "CREATE VOLUME", "MODIFY", "EXECUTE"]
  }
}

# Theres better ways to do this, but writing just the tokens nukes the vault secrets
# I wanted to preserve them and do it quickly so i could keep moving. 
# This is a quick and dirty way to merge the existing secrets with the new ones.
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