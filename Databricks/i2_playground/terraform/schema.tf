# Look up current user for ownership
data "databricks_current_user" "me" {}

# Look up the existing serverless warehouse
data "databricks_sql_warehouse" "default" {
  name = "Serverless Starter Warehouse"
}

# Create the schema if it doesn't exist
resource "databricks_schema" "openaq" {
  catalog_name = var.catalog_name
  name         = var.schema_name
  comment      = "OpenAQ air quality data — Bronze/Silver/Gold medallion"
  force_destroy = true
}

resource "databricks_volume" "openaq_checkpoints" {
  catalog_name = var.catalog_name
  schema_name  = databricks_schema.openaq.name
  name         = "checkpoints"
  volume_type  = "MANAGED"
  comment      = "Checkpoint and schema hint storage for OpenAQ Auto Loader"
}