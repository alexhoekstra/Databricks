# ==============================================================================
# federation.tf
# OPTIONAL per domain. Created only when var.federation is set (queryable DB
# sources). Mirrors the source database as a read-only foreign catalog via
# Lakehouse Federation — query live without ETL. Non-DB domains skip all of this.
# ==============================================================================

resource "databricks_connection" "this" {
  count           = local.federation_enabled ? 1 : 0
  name            = local.connection_name
  connection_type = var.federation.connection_type
  comment         = "Lakehouse Federation connection for ${var.domain}"

  options = {
    host     = var.federation.host
    port     = tostring(var.federation.port)
    user     = var.federation.user
    password = var.federation.password
  }
}

resource "databricks_catalog" "foreign" {
  count           = local.federation_enabled ? 1 : 0
  name            = local.catalog_name
  connection_name = databricks_connection.this[0].name
  comment         = "Foreign catalog mirroring ${var.domain} via Lakehouse Federation"

  depends_on = [databricks_connection.this]
}

resource "databricks_grants" "foreign" {
  count   = local.federation_enabled ? 1 : 0
  catalog = databricks_catalog.foreign[0].name

  grant {
    principal  = var.grantee
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
}
