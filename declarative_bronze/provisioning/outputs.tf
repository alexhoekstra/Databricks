# ==============================================================================
# outputs.tf
# ==============================================================================

output "databricks_role_arn" {
  value       = aws_iam_role.uc.arn
  description = "IAM role ARN assumed by Unity Catalog."
}

output "landing_bucket_name" {
  value       = aws_s3_bucket.landing.bucket
  description = "The landing bucket."
}

output "seeded_objects" {
  value       = sort([for o in aws_s3_object.seed : "s3://${o.bucket}/${o.key}"])
  description = "Sample files uploaded."
}
