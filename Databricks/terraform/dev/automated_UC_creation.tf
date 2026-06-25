# This file is a demonstration of using the unity_catalog_module to automate creation of UC objects

module "test_UC_Create_One"{
    source = "../modules/unity_catalog_module"
    existing_catalog = var.catalog_name
    schema_name = "terraform_automated_schema_1"
    schema_comment = "Terraform Automated Schema 1"
    warehouse_id = data.databricks_sql_warehouse.default.id 
    tables = {
    "users" = {
      comment = "Core customer master data"
      columns = [
        { name = "user_id", type = "STRING", comment = "Unique GUID" },
        { name = "email", type = "STRING" },
        { name = "signup_timestamp", type = "TIMESTAMP" }
      ]
    },
    "transactions" = {
      comment = "Daily ledger of consumer checkouts"
      columns = [
        { name = "transaction_id", type = "STRING" },
        { name = "user_id", type = "STRING" },
        { name = "amount", type = "DOUBLE" },
        { name = "currency", type = "STRING" }
      ]
    }
  }
}

module "test_UC_Create_two"{
    source = "../modules/unity_catalog_module"
    existing_catalog = var.catalog_name
    schema_name = "terraform_automated_schema_2"
    schema_comment = "Terraform Automated Schema 2"
    warehouse_id = data.databricks_sql_warehouse.default.id 
    tables = {
    "users" = {
      comment = "Core customer master data"
      columns = [
        { name = "user_id", type = "STRING", comment = "Unique GUID" },
        { name = "email", type = "STRING" },
        { name = "signup_timestamp", type = "TIMESTAMP" }
      ]
    },
    "transactions" = {
      comment = "Daily ledger of consumer checkouts"
      columns = [
        { name = "transaction_id", type = "STRING" },
        { name = "user_id", type = "STRING" },
        { name = "amount", type = "DOUBLE" },
        { name = "currency", type = "STRING" }
      ]
    }
  }
}

## This was meant to be an example of granting a group the ability to read only use (read) the schama
# unfortunatly The group exists in the workspace but not in Unity Catalog's identity federation
# and UC needs groups to be identity-federated which i cannot do in free tier
/*
#Grant the example users group the ability to use the schema only
resource "databricks_grant" "grant_example_users_terraform_automated_schema_1_read" {
  schema = module.test_UC_Create_One.schema_id
  principal  = data.terraform_remote_state.provisioning.outputs.example_user_group_name
  privileges = ["USE_SCHEMA"]
}*/

