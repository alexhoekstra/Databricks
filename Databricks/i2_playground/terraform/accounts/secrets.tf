#secrets.tf

# access our locally deployed vault instance
# TODO: Update address and token to .env or other secret method
provider "vault" {
  address = "http://vault:8200"
  token = "root"
}

# This resource is fetched dynamically and never saved to the .tfstate file
# TODO : update to Ephemeral KVV2 Secret resource `vault_kv_secret_v2` instead
data "vault_kv_secret_v2" "databricks_secrets" {
  mount = "kv"
  name  = "databricks"
}