#main.tf

# Terraform block used to configure some high-level behaviors of Terraform
terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      # Not specifying a version so we pull the latest 
    }
    vault = {
      source  = "hashicorp/vault"
      # Not specifying a version so we pull the latest 
    }
  }
}

# Provider authenticates automatically from DATABRICKS_HOST and DATABRICKS_TOKEN environment variables
provider "databricks" {}

resource "databricks_directory" "shared_dir" {
  path = "/Shared/Queries"
}


################### Things that didn't work ###################


#### Cant create new resources on Free Tier, This error occurs:                                                                   ##### 
#### "Error: cannot create sql endpoint: failed creating warehouse: You've hit the limit for warehouses for free usage."          #####
/* resource "databricks_sql_endpoint" "serverless" {
  name                      = "example serverless warehouse"
  cluster_size              = "2X-Small"   # smallest/cheapest for free tier
  min_num_clusters          = 1
  max_num_clusters          = 1
  auto_stop_mins            = 2            # stop quickly to conserve quota
  enable_serverless_compute = true
  warehouse_type            = "PRO"        # required for serverless
  enable_photon             = true
} */

#### This Method of catalog creation doesn't work on Free Tier - Free-tier Databricks serverless uses Databricks-managed storage  #####
#### and there is no *storage_root* value, it is empty on free tier if no external storage is configured (serverless compute)     #####
/* # Create the Databricks Catalog
resource "databricks_catalog" "sandbox" {
  name           = "sandbox_catalog"
  comment        = "This catalog is managed completely by Terraform."
  force_destroy  = true # Allows Terraform to delete it even if it contains schemas
  storage_root   = "builtin://default" 
  
  properties = {
    purpose = "testing"
    owner   = "alex.hoekstra618+databricks@gmail.com"
  }
} */

/* # Execute a SQL command to bypass the missing root metastore URL error
resource "databricks_query" "create_test_pizza_catalog_query" {
  warehouse_id  = data.databricks_sql_warehouse.default.id
  display_name  = "Create test_pizza Catalog"
  
  # The Query to create
  query_text    = "CREATE CATALOG IF NOT EXISTS test_pizza;" 
}

resource "databricks_job" "run_sql_job" {
  name = "Run Saved SQL Query Job"

  task {
    task_key = "execute_sql_query"

    sql_task {
      query {
        query_id = databricks_query.create_test_pizza_catalog_query.id
      }
      warehouse_id = data.databricks_sql_warehouse.default.id
    }
  }
}

# This triggers an on-demand job run right after creating the job
resource "null_resource" "trigger_query_run" {
  depends_on = [databricks_job.run_sql_job]

  provisioner "local-exec" {
    command = <<EOT
      curl -X POST -H "Authorization: Bearer $DATABRICKS_TOKEN" $DATABRICKS_HOST/api/2.1/jobs/run-now -d '{"job_id": "${databricks_job.run_sql_job.id}"}'
    EOT
  }
}  */


################## This block would let you grab the catalog ####################
/* # Import the UI-created catalog into your Terraform state file tracking
import {
  to = databricks_catalog.test_pizza
  id = "test_pizza"
}

# 2. Tell Terraform how to track the imported catalog and configure its drop rules
resource "databricks_catalog" "test_pizza" {
  name          = "test_pizza"
  force_destroy = true # Safely drops schemas inside if you ever run a destroy command
} */