# ==============================================================================
# versions.tf 
# ==============================================================================

terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}
