# ==============================================================================
# main.tf 
# Config-driven, per-source Unity Catalog governance + a SINGLE Lakeflow
# Declarative Pipeline that ingests every source in var.sources.
# ==============================================================================
provider "databricks" {}

data "databricks_current_user" "me" {}

module "source_ingest" {
  source = "../modules/source_ingest"

  source_name = var.target_schema
  source_infrastructure = {
    type     = var.source_domain.type
    role_arn = var.source_domain.role_arn
    bucket   = var.source_domain.bucket
  }
  source_path = local.domain_path
  grantee     = coalesce(var.grantee, data.databricks_current_user.me.user_name)
}
