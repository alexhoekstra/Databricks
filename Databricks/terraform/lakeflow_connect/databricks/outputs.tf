# ==============================================================================
# outputs.tf  (Databricks layer)
# Run: terraform output        to see all values
#      terraform output -raw <name>  to get a single value for scripting
# ==============================================================================

output "foreign_catalog_name" {
  value       = databricks_catalog.rds_foreign.name
  description = "Lakehouse Federation catalog — query live: SELECT * FROM rds_foreign.mydb.employees"
}

output "bronze_schema" {
  value       = "${databricks_schema.staging.catalog_name}.${databricks_schema.staging.name}"
  description = "UC schema where bronze Delta tables are written"
}

output "ingestion_job_id" {
  value       = databricks_job.cdc_ingestion.id
  description = "Trigger manually: databricks jobs run-now --job-id <id>"
}
