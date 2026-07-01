# Create the parent Catalog if a catalog name was provided
resource "databricks_catalog" "this" {
  count = var.new_catalog_name == null ? 0 : 1 # conditionally create this resource if a name is provided
  name = var.new_catalog_name
  comment = var.catalog_comment
}

# Create the Schema inside the Catalog
# The same pattern as above can be applied with additional vars I just wanted to demonstrate the concept
# and since i'm using free tier, I have to use the default catalog
resource "databricks_schema" "this" {
  #Use the catalog name above if it was created, otherwise use the existing catalog 
  catalog_name = var.new_catalog_name == null ? var.existing_catalog : databricks_catalog.this[0].name
  name = var.schema_name
  comment = var.schema_comment
}

# Dynamically generate tables from the provided map
resource "databricks_sql_table" "this" {
  for_each = var.tables

  catalog_name = var.new_catalog_name == null ? var.existing_catalog : databricks_catalog.this[0].name
  schema_name = databricks_schema.this.name
  name = each.key
  table_type = "MANAGED"
  data_source_format = "DELTA"
  comment = each.value.comment
  warehouse_id = var.warehouse_id

  # Nested dynamic block to build columns
  dynamic "column" {
    for_each = each.value.columns
    content {
      name = column.value.name
      type = column.value.type
      comment = lookup(column.value, "comment", null)
    }
  }
}