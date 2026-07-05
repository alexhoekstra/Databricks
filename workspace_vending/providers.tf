# ==============================================================================
# providers.tf 
# ==============================================================================

# Credentials from environment (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY),
# same as the other AWS roots in this repo.
provider "aws" {
  region = var.aws_region
}

# Account-level databricks provider — every other root talks
# to a workspace (DATABRICKS_HOST/TOKEN from env). mws_* resources only exist
# at the account API. Real auth would come from an account-admin service
# principal via DATABRICKS_CLIENT_ID / DATABRICKS_CLIENT_SECRET env vars.
# Free Edition cannot authenticate here — this root is validate-only.
provider "databricks" {
  alias      = "account"
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
}
