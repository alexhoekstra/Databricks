# ==============================================================================
# external_location.tf
# Registers the domain's storage root in Unity Catalog so the ingestion job can
# read source data. (Checkpoints live in a UC managed volume under the bronze
# schema, not here, so the source bucket can be read-only.)
# ==============================================================================

resource "databricks_external_location" "this" {
  name            = local.location_name
  url             = local.storage_root
  credential_name = databricks_storage_credential.this.name
  comment         = "Root external location for ${var.domain} — covers source data"
  skip_validation = true

  depends_on = [databricks_grants.credential]
}

resource "databricks_grants" "location" {
  external_location = databricks_external_location.this.id

  grant {
    principal  = var.grantee
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
}
