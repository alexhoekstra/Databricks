# ==============================================================================
# providers.tf
# Credentials from environment (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY)
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
