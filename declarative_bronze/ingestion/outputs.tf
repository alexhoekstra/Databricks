# ==============================================================================
# outputs.tf
# ==============================================================================

output "external_location" {
  value       = module.source_ingest.external_location_name
  description = "UC external location (domain-level, registered at the bucket root)."
}

output "storage_credential" {
  value       = module.source_ingest.storage_credential_name
  description = "UC storage credential backing the external location."
}

output "domain_path" {
  value       = module.source_ingest.source_path
  description = "Landing bucket root — the Auto Loader base path for every table."
}

output "pipeline_resource_file" {
  value       = local_file.pipeline.filename
  description = "Path to the generated DAB pipeline resource file."
}
