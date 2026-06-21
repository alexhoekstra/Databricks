# Look up current user for ownership
data "databricks_current_user" "me" {}

# Look up the existing serverless warehouse
data "databricks_sql_warehouse" "default" {
  name = "Serverless Starter Warehouse"
}

#### Open AQ Schemas ####
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

#### Initial Testing schemas ####

# This calls the Databricks API to create a table using SQL. Since we are free tier, creating catalogs
# isn't available since we dont have external storage configured
resource "null_resource" "trigger_query_run" {

  # Using local exec to run a curl command to access the databricks API 
  # Incorporating the Vault ephemeral secrets here too
  provisioner "local-exec" {
    command = <<EOT
      curl --request POST \
          --url "${ephemeral.vault_kv_secret_v2.databricks_secrets.data["host"]}/api/2.0/sql/statements" \
          --header "Authorization: Bearer ${ephemeral.vault_kv_secret_v2.databricks_secrets.data["token"]}" \
          --header "Content-Type: application/json" \
          --data '{"warehouse_id": "${data.databricks_sql_warehouse.default.id}", "statement": "CREATE CATALOG IF NOT EXISTS test_donut;", "wait_timeout": "10s", "on_wait_timeout": "CONTINUE"}'
    EOT
  }
} 

# Using a time delay to ensure the backend creates the catalog before building schemas !!!! CAN PROBABLY REMOVE!
resource "time_sleep" "wait_for_catalog" {
  depends_on      = [null_resource.trigger_query_run]
  create_duration = "10s"
}

# Create the schema inside the catalog we just created 
# TODO update to use variables for catalog name, name and comment
resource "databricks_schema" "test_donut" {
  depends_on    = [time_sleep.wait_for_catalog]
  catalog_name  = "test_donut" # Points to the catalog we just created
  name          = "testaroni"
  comment       = "Schema for test donut managed via Terraform"
  
  # Safely drops underlying tables/views if you run terraform destroy
  force_destroy = true 
}