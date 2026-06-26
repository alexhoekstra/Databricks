variable "domains" {
  description = "Configuration for each ingestion domain"
  type = map(object({
    source_type = string
    source_config = any
    target_table = string
    target_catalog = string
    schedule = string
    sp = string
  }))
}