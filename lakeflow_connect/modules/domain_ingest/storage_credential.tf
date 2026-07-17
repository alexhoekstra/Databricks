# storage_credential.tf

# Per-domain UC storage credential that Databricks needs to access the storage root of a domain's data. 
# This credential is used by the ingestion job to read source data from the external location.

# Note: The referenced IAM must be pre-existing (created by the domain's landing infra,
# see aws/ for my example). Its trust must also be self-assuming, so the
# credential validates immediately or Databricks wont be able to connect.
resource "databricks_storage_credential" "this" {
  name    = local.credential_name
  comment = "Managed by Terraform — ${var.domain} (${local.infra.type})"

  # This is the block for the AWS role, I'd probably want to change up above to a for each instead.
  dynamic "aws_iam_role" {
    for_each = local.infra.type == "aws" ? [1] : []
    content {
      role_arn = local.infra.role_arn
    }
  }
}

resource "databricks_grants" "credential" {
  storage_credential = databricks_storage_credential.this.id

  grant {
    principal  = var.grantee
    privileges = ["CREATE_EXTERNAL_TABLE", "READ_FILES", "WRITE_FILES"]
  }
}
