# ==============================================================================
# variables.tf 
# ==============================================================================

variable "databricks_account_id" {
  description = "Databricks account id. Also becomes the sts:ExternalId on every cross-account trust policy."
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region for all vended workspaces."
  type        = string
  default     = "us-east-2"
}

variable "resource_prefix" {
  description = "Prefix seeding all AWS + Databricks resource names (IAM roles, buckets, mws registrations)."
  type        = string
  default     = "dbx-vend"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.resource_prefix))
    error_message = "resource_prefix must be lowercase alphanumeric/hyphens (it seeds S3 bucket names)."
  }
}

variable "admin_group_id" {
  description = "Default numeric id of the account-level group assigned ADMIN on everyvended workspace."
  type        = number
  default     = null
}

variable "force_destroy_root_buckets" {
  description = "Allow destroying workspace root buckets even when non-empty (demo convenience)."
  type        = bool
  default     = true
}

variable "workspaces" {
  description = "Map of workspaces"

  type = map(object({
    workspace_name     = optional(string)
    region             = optional(string)
    deployment_name    = optional(string)
    pricing_tier       = optional(string)
    root_bucket_name   = optional(string)
    admin_group_id     = optional(number)
    workspace_catalogs = optional(list(string), [])
    custom_tags        = optional(map(string), {})
    network = object({
      vpc_id             = string
      private_subnet_ids = list(string)
      security_group_ids = list(string)
    })
  }))

  validation {
    condition     = alltrue([for ws in var.workspaces : length(ws.network.private_subnet_ids) >= 2])
    error_message = "Every workspace needs at least 2 private subnets, each in a different availability zone."
  }

  validation {
    condition = alltrue([
      for ws in var.workspaces :
      length(ws.network.security_group_ids) >= 1 && length(ws.network.security_group_ids) <= 5
    ])
    error_message = "Every workspace needs between 1 and 5 security groups."
  }
}
