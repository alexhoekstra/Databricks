# main.tf

# Configuration-driven, per-domain Unity Catalog wiring. Most of the logic is in the reusable module (/modules/domain_ingest). 
# By keeping this project light and the module heavy, you would have reusable logic in the module that can easily be versioned 
# and re-used across multiple projects. Also you can lock down implementations that wont break production etc. 


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

provider "databricks" {}

# This is the domain-specific Unity Catalog wiring for the lakeflow_connect pipeline. 
# One module instance per external-system "domain" in var.domains.
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
