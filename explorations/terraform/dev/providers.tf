# This file is used to specify the required providers

# Provider authenticates automatically from DATABRICKS_HOST and DATABRICKS_TOKEN environment variables
provider "databricks" {}

provider "vault" {
  address = "http://vault:8200"
  token   = "root"
}
