data "vault_kv_secret_v2" "databricks_secrets" {
  mount = var.mount
  name  = var.secret_name
}
