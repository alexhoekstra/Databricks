resource "databricks_schema" "domain_schema" {
  catalog_name = var.target_catalog
  name = "${var.domain}"
  comment = "Schema for ${var.domain}"
  properties = {
    kind = "various"
  }
}

resource "databricks_volume" "raw_volume" {
  name = "raw"
  catalog_name = var.target_catalog
  schema_name = databricks_schema.domain_schema.name
  volume_type = "MANAGED"
  comment = "Volume for ${var.domain}"
  depends_on = [ databricks_schema.domain_schema ]
}