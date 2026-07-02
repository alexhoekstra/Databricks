# ==============================================================================
# outputs.tf
# ==============================================================================

output "source_path" {
  value       = var.source_path
  description = "Resolved landing URI for this source"
}

output "external_location_name" {
  value       = databricks_external_location.this.name
  description = "Name of the UC external location created for this source."
}

output "storage_credential_name" {
  value       = databricks_storage_credential.this.name
  description = "Name of the UC storage credential created for this source."
}
