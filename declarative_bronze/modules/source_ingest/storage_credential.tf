# ==============================================================================
# storage_credential.tf
# ==============================================================================

resource "databricks_storage_credential" "this" {
  name    = local.credential_name
  comment = "Managed by Terraform — declarative_bronze/${var.source_name} (${local.infra.type})"

  dynamic "aws_iam_role" {
    for_each = local.infra.type == "aws" ? [1] : []
    content {
      role_arn = local.infra.role_arn
    }
  }
}

resource "databricks_grants" "credential" {
  count              = var.grantee == null ? 0 : 1
  storage_credential = databricks_storage_credential.this.id

  grant {
    principal  = var.grantee
    privileges = ["READ_FILES", "CREATE_EXTERNAL_TABLE"]
  }
}
