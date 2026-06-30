# ==============================================================================
# main.tf  (AWS layer)
# Configuration only — providers, variables, locals, data sources.
# No resources declared here.
#
# This is the AWS infrastructure layer. It is fully self-contained and can be
# applied on its own, before the Databricks layer in ../databricks. It declares
# no Databricks resources and requires no Databricks credentials.
#
# Resource ownership:
#   rds.tf     — security group, RDS instance, parameter group, S3 bucket
#   iam.tf     — all IAM roles, policies, attachments
#   dms.tf     — DMS replication instance, endpoints, task
#   outputs.tf — values consumed by the Databricks layer via remote state
# ==============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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

# ==============================================================================
# VARIABLES
# ==============================================================================

variable "databricks_account_id" {
  description = "Databricks account UUID — used as STS ExternalId in the IAM trust policy. Find it at accounts.databricks.com in the URL or top-right profile menu."
  type        = string
  sensitive   = true
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
