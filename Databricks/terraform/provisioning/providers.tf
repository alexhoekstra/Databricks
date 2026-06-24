#Define Providers for this project

# Provider authenticates automatically from DATABRICKS_HOST and DATABRICKS_TOKEN environment variables
# In a real project, you would likely use a secret managment solution like aws secrets manager.
provider "databricks" {}


provider "vault" {
  address = "http://vault:8200"
  token   = "root"
}
