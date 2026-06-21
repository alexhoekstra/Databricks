# access our locally deployed vault instance
# TODO: Update address and token to .env or other secret method
provider "vault" {
  address = "http://vault:8200"
  token = "root"
}

# This resource is fetched dynamically and never saved to the .tfstate file
data "vault_kv_secret_v2" "databricks_secrets" {
  mount = "kv"
  name  = "databricks"
}

# Create a Databricks secret scope
resource "databricks_secret_scope" "worldcup_scope" {
  name = "application-secrets"
}

# Create a secret within that scope
resource "databricks_secret" "kaggle_username" {
  key          = "kaggle_username"
  string_value = sensitive(data.vault_kv_secret_v2.databricks_secrets.data["kaggle_username"])
  scope        = databricks_secret_scope.worldcup_scope.name
}

# Create a secret within that scope
resource "databricks_secret" "kaggle_key" {
  key          = "kaggle_key"
  string_value = sensitive(data.vault_kv_secret_v2.databricks_secrets.data["kaggle_key"])
  scope        = databricks_secret_scope.worldcup_scope.name
}

