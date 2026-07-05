# ==============================================================================
# versions.tf 
# Provider requirements for the workspace vending module. The module configures
# no providers itself — the root passes in the *account-level* `databricks`
# provider (host = accounts.cloud.databricks.com) and a configured `aws`
# provider. `time` handles IAM eventual-consistency waits. Version pins live at
# the root.
# ==============================================================================

terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
    aws = {
      source = "hashicorp/aws"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}
