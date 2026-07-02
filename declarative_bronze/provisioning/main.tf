# ==============================================================================
# main.tf
# ==============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ==============================================================================
# VARIABLES
# ==============================================================================

variable "region" {
  description = "AWS region for the landing buckets. Set to your Databricks workspace's region to avoid cross-region S3 egress."
  type        = string
  default     = "us-east-2"
}

variable "databricks_account_id" {
  description = "Databricks account id."
  type        = string
  sensitive   = true
}

variable "landing_bucket" {
  description = "S3 bucket for the whole domain."
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role Databricks Unity Catalog assumes to read the landing bucket."
  type        = string
  default     = "defense-uc-s3-access"
}

variable "force_destroy_bucket" {
  description = "Allow `terraform destroy` to delete the non-empty landing bucket."
  type        = bool
  default     = true
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "aws_caller_identity" "current" {}

# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  # Constructed role ARN, referenced in the trust policy, to avoid a
  # resource → data → resource cycle. Same value as aws_iam_role.uc.arn.
  uc_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.role_name}"

  # Bucket ARN (and its object-level form) for the read policy.
  bucket_arns     = ["arn:aws:s3:::${var.landing_bucket}"]
  bucket_arns_obj = ["arn:aws:s3:::${var.landing_bucket}/*"]
}
