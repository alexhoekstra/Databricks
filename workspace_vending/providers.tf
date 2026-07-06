# ==============================================================================
# providers.tf 
# ==============================================================================

# Credentials from environment (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY),
provider "aws" {
  region = var.aws_region
}

# Account-level databricks provider 
provider "databricks" {
  alias      = "account"
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
}
