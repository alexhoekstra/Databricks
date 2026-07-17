# variables.tf

variable "domain" {
  description = "Domain (external-system) name."
  type        = string
}

# source_infrastructure  is a map of infrastructure-specific settings. 
# "type" selects the wiring (credential auth block + storage URI info for AWS right now only).
# Keeping this as a "knob" that can be wired up to other external source systems
# by using the optional values in the type block. 
variable "source_infrastructure" {
  description = "Where the domain's data lands and how UC authenticates"
  type = object({
    type = string
    # aws-specific 
    role_arn = optional(string) # IAM role the storage credential assumes
    bucket   = optional(string) # S3 bucket the role can access
    prefix   = optional(string) # prefix under the bucket where source data lands
  })

  # Since I only wired up AWS for now, Make sure we dont try anything else here
  validation {
    condition     = contains(["aws"], var.source_infrastructure.type)
    error_message = "Only source_infrastructure.type = \"aws\" is supported right now."
  }

  # Make sure all the AWS Information is there since its "optional"
  validation {
    condition = var.source_infrastructure.type != "aws" || alltrue([
      var.source_infrastructure.role_arn != null,
      var.source_infrastructure.bucket != null,
      var.source_infrastructure.prefix != null,
    ])
    error_message = "For type = \"aws\", role_arn, bucket, and prefix are all required."
  }
}

# Since i cant "create" a catalog, default to main
variable "target_catalog" {
  description = "Unity Catalog catalog the bronze schema/tables live in."
  type        = string
  default     = "main"
}

variable "source_schema" {
  description = "Source schema/database name."
  type        = string
}

variable "grantee" {
  description = "Principal (user email or service principal) granted access to the credential, location, and federated catalog."
  type        = string
}

# Optional Lakehouse Federation — only created when enabled.
variable "enable_federation" {
  description = "Whether to create a Lakehouse Federation connection + foreign catalog for this domain."
  type        = bool
  default     = false
}

variable "federation" {
  description = "Federation connection config; required when enable_federation = true, else null."
  type = object({
    connection_type = string
    host            = string
    port            = number
    user            = string
    password        = string
  })
  default   = null
  sensitive = true
}

# Has to be a QUARTZ cron expression...
variable "schedule" {
  description = "Quartz cron expression for the ingestion job schedule."
  type        = string
  default     = "0 0 6 * * ?"
}

# Where to render the generated per-domain job resource file.
variable "bundle_resources_dir" {
  description = "Directory (relative to the modules caller root) where the per-domain DAB job YAML is written."
  type        = string
  default     = "../bundles/lakeflow_connect/resources"
}

#This is a bit janky, I dont like the path being relative to a generated YAML. But keeping it like this for now
variable "wheel_dependency" {
  description = "Path (relative to the generated job YAML in the bundle's resources/) to the cdc_bronze_ingest wheel glob."
  type        = string
  default     = "../cdc_bronze_ingest/dist/cdc_bronze_ingest-*.whl"
}
