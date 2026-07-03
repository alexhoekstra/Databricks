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
  description = "Pipeline-level run-mode toggle. false=triggered (auto-stops). true=continuous, but a continuous bronze update holds the single account-wide active-update slot and starves the curated (silver) pipeline in bundle_curated — use it only for bounded demos while bundle_curated is undeployed. The declarative_medallion orchestration job owns scheduling."
  type        = bool
  default     = false
}

variable "fail_on_empty" {
  description = "When true, the pipeline raises if discovery finds no files (guards against silent data loss). Set false only for bootstrap runs against an empty bucket."
  type        = bool
  default     = true
}

variable "include_tables" {
  description = "Optional allow-list of file stems to ingest (empty = all). Joined into the pipeline's include_tables config key."
  type        = list(string)
  default     = []
}

variable "exclude_tables" {
  description = "Optional deny-list of file stems to skip (empty = none; wins over include_tables). Joined into the pipeline's exclude_tables config key."
  type        = list(string)
  default     = []
}

variable "notification_emails" {
  description = "Emails to notify on pipeline update/flow failure. Empty = no notifications block is emitted."
  type        = list(string)
  default     = []
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
