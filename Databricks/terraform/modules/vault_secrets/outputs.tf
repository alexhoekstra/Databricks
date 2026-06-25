output "secrets" {
  description = "All key/value pairs from the Vault KV v2 secret."
  value       = data.vault_kv_secret_v2.databricks_secrets.data
  sensitive   = true
}
