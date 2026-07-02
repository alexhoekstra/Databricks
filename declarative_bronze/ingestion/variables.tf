# ==============================================================================
# variables.tf
# ==============================================================================

variable "source_domain" {
  description = "Shared landing infra + file format for the whole domain."
  type = object({
    type     = string
    role_arn = string
    bucket   = string
    format   = optional(string, "parquet")
  })
}

variable "target_catalog" {
  description = "Unity Catalog catalog for the bronze tables."
  type        = string
  default     = "main"
}

variable "target_schema" {
  description = "Shared UC schema the pipeline writes bronze tables into."
  type        = string
  default     = "declarative_bronze"
}

variable "continuous" {
  description = "Pipeline-level run-mode toggle"
  type        = bool
  default     = false
}

variable "grantee" {
  description = "Principal for UC grants. Defaults to the running identity when null."
  type        = string
  default     = null
}

variable "bundle_resources_dir" {
  description = "Where the generated pipeline resource file is written (relative to this root)."
  type        = string
  default     = "../bundle/resources"
}
