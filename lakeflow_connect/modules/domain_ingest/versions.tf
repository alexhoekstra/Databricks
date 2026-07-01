# ==============================================================================
# versions.tf
# Provider requirements for the domain_ingest module. The module configures no
# providers itself — the root passes in a configured `databricks` provider.
# `local` is used to render the per-domain DAB job resource file.
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
