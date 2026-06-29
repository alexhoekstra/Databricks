# ==============================================================================
# outputs.tf
# All output values in one place.
# Run: terraform output        to see all values
#      terraform output -raw <name>  to get a single value for scripting
# ==============================================================================

# ==============================================================================
# AWS — RDS
# ==============================================================================

output "db_endpoint" {
  value       = aws_db_instance.default.endpoint
  description = "RDS MySQL connection endpoint (host:port)"
}

output "db_name" {
  value       = aws_db_instance.default.db_name
  description = "MySQL database name"
}

# ==============================================================================
# AWS — S3
# ==============================================================================

output "s3_bucket_name" {
  value       = aws_s3_bucket.main.bucket
  description = "S3 bucket used for DMS CDC output and Auto Loader checkpoints"
}

output "dms_cdc_s3_prefix" {
  value       = "s3://${aws_s3_bucket.main.bucket}/dms-cdc/"
  description = "S3 prefix where DMS writes CDC Parquet files"
}

output "checkpoint_s3_prefix" {
  value       = "s3://${aws_s3_bucket.main.bucket}/checkpoints/cdc-bronze/"
  description = "S3 prefix for Auto Loader checkpoints — clear this to reprocess all files"
}

# ==============================================================================
# AWS — IAM
# ==============================================================================

output "databricks_role_arn" {
  value       = aws_iam_role.databricks_access.arn
  description = "IAM role ARN assumed by Databricks Unity Catalog for S3 access"
}

# ==============================================================================
# AWS — DMS
# ==============================================================================

output "dms_task_arn" {
  value       = aws_dms_replication_task.hr_cdc.replication_task_arn
  description = <<-EOT
    DMS replication task ARN.
    Start:  aws dms start-replication-task --replication-task-arn <arn> --start-replication-task-type start-replication
    Reload: aws dms start-replication-task --replication-task-arn <arn> --start-replication-task-type reload-target
    Stop:   aws dms stop-replication-task  --replication-task-arn <arn>
  EOT
}

# ==============================================================================
# DATABRICKS
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
