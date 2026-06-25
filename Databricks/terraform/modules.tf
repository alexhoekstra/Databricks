# Configures modules for this project

module "vault_secrets" {
  source      = "./modules/vault_secrets"
  mount       = "kv"
  secret_name = "databricks"
}