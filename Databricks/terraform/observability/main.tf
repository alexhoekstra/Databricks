#main.tf

# Terraform block used to configure some high-level behaviors of Terraform
terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      # Not specifying a version so we pull the latest in a real situation you should pin to a specific version 
    }
  }
}
