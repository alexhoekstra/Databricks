output "catalog_id" {
  value = var.new_catalog_name == null ? var.existing_catalog : databricks_catalog.this[0].id
}

output "schema_id" {
  value = databricks_schema.this.id
}

output "table_ids" {
  value = { for k, v in databricks_sql_table.this : k => v.id }
}