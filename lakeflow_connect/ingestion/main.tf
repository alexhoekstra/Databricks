# ==============================================================================
# main.tf  (ingestion root)
# Configuration-driven, per-domain Unity Catalog wiring for the lakeflow_connect
# pipeline. One module instance per external-system "domain" in var.domains.
#
# This root owns NO AWS resources and needs no AWS provider — each domain's
# landing infra (bucket + IAM role) is pre-existing (see ../aws for the worked
# example). The module creates the per-domain UC storage credential + external
# location + optional federation, and generates the DAB job resource file.
#
# Apply order: this root first (creates UC governance + generates job ymls), then
# `databricks bundle deploy` in lakeflow_connect/bundles/lakeflow_connect.
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

# Authenticates from environment variables:
#   export DATABRICKS_HOST=https://your-workspace.cloud.databricks.com
#   export DATABRICKS_TOKEN=dapi...
provider "databricks" {}

module "domain_ingest" {
  for_each = var.domains
  source   = "../modules/domain_ingest"

  domain                = each.key
  source_infrastructure = each.value.source_infrastructure
  target_catalog        = try(each.value.target_catalog, "main")
  source_schema         = each.value.source_schema
  grantee               = try(each.value.grantee, null)
  federation            = try(each.value.federation, null)
  enable_federation     = try(each.value.federation, null) != null
  schedule              = try(each.value.schedule, "0 0 6 * * ?")
}
