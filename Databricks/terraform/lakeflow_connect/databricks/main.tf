# ==============================================================================
# main.tf  (Databricks layer)
# Configuration only — providers, variables, remote state, locals.
# No resources declared here.
#
# This is the Databricks infrastructure layer. It provisions only Unity Catalog
# and job resources and declares NO AWS resources. Every AWS value it needs
# (S3 bucket, IAM role, RDS endpoint/credentials) is read from the AWS layer's
# state via terraform_remote_state — so applying this layer never creates or
# modifies AWS infrastructure.
#
# Apply order: ../aws must be applied first so its state file exists.
#
# Resource ownership:
#   databricks.tf — all Databricks Unity Catalog and job resources
#   outputs.tf    — all output values
# ==============================================================================

terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

# ==============================================================================
# PROVIDERS
# ==============================================================================

# Authenticates from environment variables before running terraform apply:
#   export DATABRICKS_HOST=https://your-workspace.cloud.databricks.com
#   export DATABRICKS_TOKEN=dapi...
provider "databricks" {}

# ==============================================================================
# REMOTE STATE — AWS layer
# Reads the outputs of the AWS layer (../aws) from its local state file.
# This is the only link between the two layers; nothing here touches AWS APIs.
# ==============================================================================

data "terraform_remote_state" "aws" {
  backend = "local"

  config = {
    path = "../aws/terraform.tfstate"
  }
}

# ==============================================================================
# VARIABLES
# ==============================================================================

variable "databricks_user_email" {
  description = "Your Databricks user email — granted privileges on the storage credential and UC resources."
  type        = string
  default     = "alex.hoekstra618+databricks@gmail.com"
}

# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  # Shorthand for AWS layer outputs consumed below.
  aws = data.terraform_remote_state.aws.outputs
}
