# ==============================================================================
# backend.tf
# ==============================================================================

# Settings come from -backend-config (backend.hcl locally, CI flags in the workflow).
terraform {
  backend "s3" {}
}
