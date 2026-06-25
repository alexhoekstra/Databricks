variable "openaq_location_ids" {
  description = "OpenAQ location IDs to ingest — replace with real IDs from explore.openaq.org"
  type        = list(number)
  default     = [12345, 67890]
}

variable "catalog_name" {
  description = "Unity Catalog catalog to use"
  type        = string
  default     = "main"
}

variable "aq_schema_name" {
  description = "Air Quality Schema name under the catalog"
  type        = string
  default     = "openaq"
}

variable "worldcup_schema_name" {
  description = "World Cup Schema name under the catalog"
  type        = string
  default     = "worldcup"
}