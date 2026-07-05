# ==============================================================================
# providers.tf  (network root)
# Credentials from environment (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY),
# same as the other AWS roots.
# ==============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project    = "network"
      managed_by = "terraform"
    }
  }
}
