# outputs.tf

output "db_endpoint" {
  value       = aws_db_instance.default.endpoint
  description = "RDS MySQL connection endpoint (host:port)"
}

output "db_name" {
  value       = aws_db_instance.default.db_name
  description = "MySQL database name"
}

output "db_address" {
  value       = aws_db_instance.default.address
  description = "RDS MySQL hostname"
}

output "db_port" {
  value       = aws_db_instance.default.port
  description = "RDS MySQL port"
}

output "db_username" {
  value       = aws_db_instance.default.username
  description = "RDS MySQL admin username"
}

output "db_password" {
  value       = aws_db_instance.default.password
  description = "RDS MySQL admin password"
  sensitive   = true
}

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
  description = "S3 prefix for Auto Loader checkpoints"
}

output "databricks_role_arn" {
  value       = aws_iam_role.databricks_access.arn
  description = "IAM role ARN assumed by Databricks Unity Catalog for S3 access"
}

output "databricks_role_name" {
  value       = aws_iam_role.databricks_access.name
  description = "IAM role name — used as the Databricks UC storage credential name"
}

output "dms_task_arn" {
  value       = aws_dms_replication_task.hr_cdc.replication_task_arn
  description = "DMS replication task ARN."
}
