# ==============================================================================
# grants.tf
# ==============================================================================

resource "databricks_grant" "catalog" {
  for_each = local.user_catalog_grants

  catalog    = each.value.catalog
  principal  = databricks_user.member[each.value.email].user_name
  privileges = ["USE_CATALOG"]
}

resource "databricks_grant" "schema" {
  for_each = local.user_schema_grants

  # databricks_schema.id is "catalog.schema"
  schema     = databricks_schema.managed[each.value.schema_key].id
  principal  = databricks_user.member[each.value.email].user_name
  privileges = each.value.privileges
}
