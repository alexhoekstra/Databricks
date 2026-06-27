# Terraform block used to configure some high-level behaviors of Terraform
terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      # Not specifying a version so we pull the latest in prod you should pin to a specific version 
    }
  }
}

module "domain_batch_ingest" {
  depends_on = [
    databricks_notebook.generic_extractor, 
    databricks_notebook.generic_autoloader]

  for_each = var.domains

  source = "../modules/domain_batch_ingest"
  domain = each.key
  source_type= each.value.source_type
  source_config = jsonencode(each.value.source_config)
  target_catalog = each.value.target_catalog
  schedule = each.value.schedule
  sp = try(each.value.sp, null)
}