# ==============================================================================
# versions.tf 
# ==============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.120"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
