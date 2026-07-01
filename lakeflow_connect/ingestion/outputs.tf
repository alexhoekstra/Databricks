# ==============================================================================
# outputs.tf  (ingestion root)
# Per-domain summaries, keyed by domain name.
# ==============================================================================

output "domains" {
  description = "Per-domain UC objects + generated job file, keyed by domain."
  value = {
    for name, mod in module.domain_ingest : name => {
      storage_credential = mod.storage_credential_name
      external_location  = mod.external_location_name
      external_url       = mod.external_location_url
      foreign_catalog    = mod.foreign_catalog
      bronze_schema      = mod.bronze_schema
      source_path        = mod.source_path
      job_resource_file  = mod.job_resource_file
    }
  }
}
