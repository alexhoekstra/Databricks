# ==============================================================================
# outputs.tf  (AWS layer)
# All output values in one place.
# Run: terraform output        to see all values
#      terraform output -raw <name>  to get a single value for scripting
#
# The Databricks layer (../databricks) reads this state via terraform_remote_state
# and consumes the outputs below. Adding a new cross-layer dependency means
# exposing it here first.
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

output "db_address" {
  value       = aws_db_instance.default.address
  description = "RDS MySQL hostname (no port) — used by the Databricks UC connection and DMS"
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
  description = "RDS MySQL admin password — consumed by the Databricks UC connection via remote state"
  sensitive   = true
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

output "databricks_role_name" {
  value       = aws_iam_role.databricks_access.name
  description = "IAM role name — used as the Databricks UC storage credential name"
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
