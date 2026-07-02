# ==============================================================================
# external_location.tf
# ==============================================================================

resource "databricks_external_location" "this" {
  name            = local.location_name
  url             = var.source_path
  credential_name = databricks_storage_credential.this.name
  comment         = "External location for declarative_bronze/${var.source_name}"
  skip_validation = true

  depends_on = [databricks_grants.credential]
}

resource "databricks_grants" "location" {
  count             = var.grantee == null ? 0 : 1
  external_location = databricks_external_location.this.id

  grant {
    principal  = var.grantee
    privileges = ["READ_FILES", "CREATE_EXTERNAL_TABLE"]
  }
}
