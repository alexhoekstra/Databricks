# Create a Databricks secret scope
resource "databricks_secret_scope" "worldcup_scope" {
  name = "application-secrets"
}

# Create a secret within that scope
resource "databricks_secret" "kaggle_username" {
  key          = "kaggle_username"
  string_value = sensitive(module.vault_secrets.secrets["kaggle_username"])
  scope        = databricks_secret_scope.worldcup_scope.name
}

# Create a secret within that scope
resource "databricks_secret" "kaggle_key" {
  key          = "kaggle_key"
  string_value = sensitive(module.vault_secrets.secrets["kaggle_key"])
  scope        = databricks_secret_scope.worldcup_scope.name
}

