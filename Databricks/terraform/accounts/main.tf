#main.tf

# Terraform block used to configure some high-level behaviors of Terraform
terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      # Not specifying a version so we pull the latest in prod you should pin to a specific version 
    }
    vault = {
      source  = "hashicorp/vault"
      # Not specifying a version so we pull the latest in prod you should pin to a specific version 
    }
  }
}

# Provider authenticates automatically from DATABRICKS_HOST and DATABRICKS_TOKEN environment variables
# In a real project, you would likely use a secret managment solution like aws secrets manager.
provider "databricks" {}
