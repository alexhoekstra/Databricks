# ==============================================================================
# variables.tf
# Inputs for one domain (one external source system).
# ==============================================================================

variable "domain" {
  description = "Logical domain / external-system name (e.g. hr, salesforce, proposals)."
  type        = string
}

# ------------------------------------------------------------------------------
# source_infrastructure — cloud-pluggable discriminator.
# `type` selects the cloud-specific wiring (credential auth block + storage URI
# scheme). Only "aws" is implemented today; the type-specific fields are optional
# so future types (azure, gcp) slot in without changing this interface.
# ------------------------------------------------------------------------------
variable "source_infrastructure" {
  description = "Where the domain's data lands and how UC authenticates to it. Only type = \"aws\" is supported now."
  type = object({
    type = string
    # aws-specific (pre-existing landing infra):
    role_arn = optional(string) # IAM role the storage credential assumes
    bucket   = optional(string) # S3 bucket the role can access
    prefix   = optional(string) # prefix under the bucket where source data lands
  })

  validation {
    condition     = contains(["aws"], var.source_infrastructure.type)
    error_message = "Only source_infrastructure.type = \"aws\" is supported right now."
  }

  validation {
    condition = var.source_infrastructure.type != "aws" || alltrue([
      var.source_infrastructure.role_arn != null,
      var.source_infrastructure.bucket != null,
      var.source_infrastructure.prefix != null,
    ])
    error_message = "For type = \"aws\", role_arn, bucket, and prefix are all required."
  }
}

variable "target_catalog" {
  description = "Unity Catalog catalog the bronze schema/tables live in."
  type        = string
  default     = "main"
}

variable "source_schema" {
  description = "Source schema/database name (passed to the ingestion job for lineage/parameters)."
  type        = string
}

variable "grantee" {
  description = "Principal (user email or service principal) granted access to the credential, location, and federated catalog."
  type        = string
}

# Optional Lakehouse Federation — only created when enabled (DB sources only).
# `enable_federation` is a separate NON-sensitive bool because Terraform forbids
# sensitive values in `count` (the federation object is sensitive for its password).
variable "enable_federation" {
  description = "Whether to create a Lakehouse Federation connection + foreign catalog for this domain."
  type        = bool
  default     = false
}

variable "federation" {
  description = "Federation connection config; required when enable_federation = true, else null."
  type = object({
    connection_type = string # e.g. MYSQL
    host            = string
    port            = number
    user            = string
    password        = string
  })
  default   = null
  sensitive = true
}

variable "schedule" {
  description = "Quartz cron expression for the ingestion job schedule."
  type        = string
  default     = "0 0 6 * * ?"
}

# ------------------------------------------------------------------------------
# DAB bridge — where to render the generated per-domain job resource file.
# ------------------------------------------------------------------------------
variable "bundle_resources_dir" {
  description = "Directory (relative to the ingestion root) where the per-domain DAB job YAML is written."
  type        = string
  default     = "../bundles/lakeflow_connect/resources"
}

variable "wheel_dependency" {
  description = "Path (relative to the generated job YAML in the bundle's resources/) to the cdc_bronze_ingest wheel glob."
  type        = string
  default     = "../cdc_bronze_ingest/dist/cdc_bronze_ingest-*.whl"
}
