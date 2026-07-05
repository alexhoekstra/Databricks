# ==============================================================================
# versions.tf  (databricks_vpc module)
# Provider requirements for the Databricks VPC module. The module configures no
# providers itself — the root passes in a configured `aws` provider. Version
# pins live at the root.
# ==============================================================================

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
