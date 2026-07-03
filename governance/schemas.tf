# ==============================================================================
# schemas.tf
# ==============================================================================

# Catalogs are UI-created; Terraform owns only the schemas inside them.
resource "databricks_schema" "managed" {
  for_each     = local.schema_defs
  catalog_name = each.value.catalog
  name         = each.value.schema
  comment      = each.value.comment

  # tables are loaded by sample_data/, outside Terraform state
  force_destroy = true
}
