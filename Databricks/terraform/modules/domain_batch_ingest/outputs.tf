output "catalog_id" {
  value = var.target_catalog # if we could create a new catalog, it would go here
  description = "The ID of the catalog the resources were created under"
}

output "schema_id" {
  value = databricks_schema.domain_schema.id
  description = "The ID of the schema the resources were created under"
}

output "job_id" {
  value = databricks_job.domain_batch_ingest.id
  description = "The ID of the job the resources were created under"
}