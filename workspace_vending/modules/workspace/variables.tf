# ==============================================================================
# variables.tf
# ==============================================================================

variable "workspace_key" {
  description = "Short key for this workspace (the var.workspaces map key at the root). Seeds AWS + Databricks resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.workspace_key))
    error_message = "workspace_key must be lowercase alphanumeric/hyphens (it seeds S3 bucket and IAM role names)."
  }
}

variable "workspace_name" {
  description = "Human-readable workspace name shown in the account console."
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account id. Doubles as the sts:ExternalId on the cross-account trust policy."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "AWS region the workspace is deployed into (must match the region of the network + root bucket)."
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for AWS + Databricks resource names created by this module."
  type        = string
}

variable "root_bucket_name" {
  description = "Name of the workspace root (DBFS) S3 bucket this module creates."
  type        = string
}

variable "force_destroy_root_bucket" {
  description = "Allow destroying the root bucket even when non-empty (demo convenience)."
  type        = bool
  default     = true
}

variable "deployment_name" {
  description = "Optional deployment name -> <deployment_name>.cloud.databricks.com. Null lets Databricks pick one. Requires the account to have a deployment-name prefix enabled."
  type        = string
  default     = null
}

variable "pricing_tier" {
  description = "Optional pricing tier (e.g. ENTERPRISE). Null -> API default for the account."
  type        = string
  default     = null
}

variable "custom_tags" {
  description = "Tags applied to the workspace (propagated to workspace compute by Databricks)."
  type        = map(string)
  default     = {}
}

variable "network" {
  description = <<-EOT
    Customer-managed VPC wiring for the workspace. Shaped field-for-field like
    the future network/ module's outputs (Project 3), so wiring it up becomes
    `network = module.network_dev` at the root.
  EOT

  type = object({
    vpc_id             = string
    private_subnet_ids = list(string)
    security_group_ids = list(string)
  })

  validation {
    condition     = length(var.network.private_subnet_ids) >= 2
    error_message = "Databricks requires at least 2 private subnets, each in a different availability zone."
  }

  validation {
    condition     = length(var.network.security_group_ids) >= 1 && length(var.network.security_group_ids) <= 5
    error_message = "Databricks accepts between 1 and 5 security groups per workspace network."
  }
}

variable "admin_group_id" {
  description = <<-EOT
    Numeric id of the account-level group to assign ADMIN on the new workspace
    (Account console -> Groups). Null skips the assignment. A raw number by
    design: a `data "databricks_group"` lookup would call the account SCIM API
    at plan time, which 401s on Free Edition (see governance/README.md).
  EOT
  type        = number
  default     = null
}

variable "workspace_catalogs" {
  description = <<-EOT
    Catalogs to bind to this workspace. Consumed only by the documented
    catalog-binding stub in baseline.tf today — binding needs a workspace-level
    provider, which can't be wired per for_each instance. Kept in the contract
    so the intent survives into the follow-up root that would apply it.
  EOT
  type        = list(string)
  default     = []
}
