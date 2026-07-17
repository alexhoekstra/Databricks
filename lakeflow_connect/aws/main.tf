# main.tf  
# This is the AWS infrastructure layer. It's meant to be an example of an existing org.  
# Databricks access would be the only thing that would need to be configured if it truely was already existing (see iam.tf)
#
# Resource ownership:
#   rds.tf     — security group, RDS instance, parameter group, S3 bucket
#   iam.tf     — all IAM roles, policies, attachments ---Only thing that would need to be added if Domain was pre-existing
#   dms.tf     — DMS replication instance, endpoints, task
#   outputs.tf — values consumed by the Databricks layer via remote state

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
# PROVIDERS
provider "aws" {
  region = "us-east-2"
}
# VARIABLES
variable "databricks_account_id" {
  description = "Databricks account UUID — used as STS ExternalId in the IAM trust policy."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "RDS MySQL admin password."
  type        = string
  sensitive   = true
}

# DATA SOURCES
# Resolves the current AWS account ID — used to make the S3 bucket name
# globally unique and to construct the IAM role ARN
data "aws_caller_identity" "current" {}


# LOCALS
locals {
  databricks_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/databricks-external-data-access"
}
