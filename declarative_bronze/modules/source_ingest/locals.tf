# ==============================================================================
# locals.tf
# ==============================================================================

locals {
  infra = var.source_infrastructure
  credential_name = "declbronze_${var.source_name}_cred"
  location_name   = "declbronze_${var.source_name}_loc"
}
