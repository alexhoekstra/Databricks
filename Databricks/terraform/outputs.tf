output "job_url" {
  value       = databricks_job.openaq_pipeline.url
  description = "URL to the OpenAQ medallion pipeline job"
}

output "bronze_notebook_path" {
  value = databricks_notebook.bronze_openaq.path
}

output "warehouse_id" {
  value = data.databricks_sql_warehouse.default.id
}