terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0" ## allow for minor version updates, but not major version updates
    }
  }
}