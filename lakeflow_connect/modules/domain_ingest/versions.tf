# versions.tf

# Configure the required providers.  Currently uses latest but would
# be best to lock it to specific version
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
