# ==============================================================================
# main.tf
# Configuration only — providers, variables, locals, data sources.
# No resources declared here.
#
# Resource ownership:
#   rds.tf        — security group, RDS instance, parameter group, S3 bucket
#   iam.tf        — all IAM roles, policies, attachments
#   dms.tf        — DMS replication instance, endpoints, task
#   databricks.tf — all Databricks Unity Catalog and job resources
#   outputs.tf    — all output values
# ==============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# ==============================================================================
# PROVIDERS
# ==============================================================================

provider "aws" {
  region = "us-east-2"
}

# Authenticates from environment variables before running terraform apply:
#   export DATABRICKS_HOST=https://your-workspace.cloud.databricks.com
#   export DATABRICKS_TOKEN=dapi...
provider "databricks" {}

# ==============================================================================
# VARIABLES
# ==============================================================================

variable "databricks_account_id" {
  description = "Databricks account UUID — used as STS ExternalId in the IAM trust policy. Find it at accounts.databricks.com in the URL or top-right profile menu."
  type        = string
  sensitive   = true
}

variable "databricks_user_email" {
  description = "Your Databricks user email — granted privileges on the storage credential and UC resources."
  type        = string
  default     = "alex.hoekstra618+databricks@gmail.com"
}

variable "db_password" {
  description = "RDS MySQL admin password. Pass via terraform.tfvars (gitignored) or TF_VAR_db_password env var."
  type        = string
  sensitive   = true
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

# Resolves the current AWS account ID — used to make the S3 bucket name
# globally unique and to construct the IAM role ARN without a cycle.
data "aws_caller_identity" "current" {}

# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  # Constructed IAM role ARN used in the trust policy to avoid a
  # resource → data → resource cycle. Produces the same value as
  # aws_iam_role.databricks_access.arn without a circular dependency.
  databricks_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/databricks-external-data-access"
}
