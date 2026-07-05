# ==============================================================================
# outputs.tf
# ==============================================================================

output "workspace_id" {
  description = "Numeric Databricks workspace id."
  value       = databricks_mws_workspaces.this.workspace_id
}

output "workspace_url" {
  description = "Workspace URL (https://<deployment>.cloud.databricks.com)."
  value       = databricks_mws_workspaces.this.workspace_url
}

output "credentials_id" {
  description = "Id of the registered cross-account credentials."
  value       = databricks_mws_credentials.this.credentials_id
}

output "storage_configuration_id" {
  description = "Id of the registered root-bucket storage configuration."
  value       = databricks_mws_storage_configurations.this.storage_configuration_id
}

output "network_id" {
  description = "Id of the registered customer-managed VPC network."
  value       = databricks_mws_networks.this.network_id
}

output "cross_account_role_arn" {
  description = "ARN of the cross-account credentials IAM role."
  value       = aws_iam_role.cross_account.arn
}

output "root_bucket_name" {
  description = "Name of the workspace root (DBFS) bucket."
  value       = aws_s3_bucket.root.bucket
}
