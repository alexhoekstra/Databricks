# ==============================================================================
# variables.tf 
# ==============================================================================

variable "databricks_account_id" {
  description = "Databricks account id (Account console -> top-right). Also becomes the sts:ExternalId on every cross-account trust policy."
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region for all vended workspaces (single-region for now; see guard.tf)."
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
  description = <<-EOT
    Default numeric id of the account-level group assigned ADMIN on every
    vended workspace (Account console -> Groups -> group id). Overridable per
    workspace. Null skips the assignment. A raw number rather than a
    data "databricks_group" lookup because the lookup calls the account SCIM
    API at plan time — a 401 on Free Edition (see governance/README.md).
  EOT
  type        = number
  default     = null
}

variable "force_destroy_root_buckets" {
  description = "Allow destroying workspace root buckets even when non-empty (demo convenience)."
  type        = bool
  default     = true
}

variable "workspaces" {
  description = <<-EOT
    Map of workspace key -> configuration. The single source of truth for which
    workspaces exist: adding a workspace = adding one entry here. Each entry
    vends the AWS prerequisites (cross-account IAM role + root bucket) and the
    four account-level registrations (credentials, storage configuration,
    network, workspace).

    The nested `network` object is shaped field-for-field like the future
    network/ module's outputs (Project 3): once that exists, an entry's network
    becomes `network = module.network_dev` instead of hardcoded ids.

    NOTE: not marked sensitive because it is used as a for_each key set
    (Terraform forbids sensitive for_each). Keep terraform.tfvars gitignored;
    the account id is marked sensitive separately.
  EOT

  type = map(object({
    workspace_name     = optional(string)           # default: the map key
    region             = optional(string)           # default: var.aws_region (must match it — see guard.tf)
    deployment_name    = optional(string)           # <deployment_name>.cloud.databricks.com
    pricing_tier       = optional(string)           # null -> API default
    root_bucket_name   = optional(string)           # default: "<resource_prefix>-<key>-root"
    admin_group_id     = optional(number)           # overrides var.admin_group_id
    workspace_catalogs = optional(list(string), []) # consumed by the catalog-binding stub only
    custom_tags        = optional(map(string), {})
    network = object({
      vpc_id             = string
      private_subnet_ids = list(string) # >= 2, each in a different AZ
      security_group_ids = list(string) # 1..5
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
