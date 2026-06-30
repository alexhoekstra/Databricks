# ==============================================================================
# outputs.tf
# ==============================================================================

output "storage_credential_name" {
  value       = databricks_storage_credential.this.name
  description = "Name of the UC storage credential created for this domain."
}

output "external_location_name" {
  value       = databricks_external_location.this.name
  description = "Name of the UC external location created for this domain."
}

output "external_location_url" {
  value       = databricks_external_location.this.url
  description = "Storage root URL registered as the external location."
}

output "foreign_catalog" {
  value       = local.federation_enabled ? databricks_catalog.foreign[0].name : null
  description = "Federated catalog name (null when federation is disabled for this domain)."
}

output "bronze_schema" {
  value       = "${var.target_catalog}.${local.target_schema}"
  description = "Fully-qualified bronze schema the DAB job writes to (schema itself is DAB-owned)."
}

output "source_path" {
  value       = local.source_path
  description = "Resolved source URI passed to the ingestion job."
}

output "job_resource_file" {
  value       = local_file.job.filename
  description = "Path to the generated DAB job resource file."
}
