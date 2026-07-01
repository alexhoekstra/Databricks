#Variables required for this module

variable "new_catalog_name" {
  type = string
  description = "The name of the catalog"
  default = null
}

variable "existing_catalog" {
  type = string
  description = "The name of the existing catalog"
  default = null

  validation {
    # Check that exactly one variable is non-null
    condition = (
      (var.new_catalog_name != null && var.existing_catalog == null) ||
      (var.new_catalog_name == null && var.existing_catalog != null)
    )
    error_message = "You must provide either 'new_catalog_name' (to create a catalog) OR 'existing_catalog' (to use an existing catalog), but not both."
  }
}

variable "catalog_comment" {
  type = string
  default = "Default Comment for the Catalog"
}

variable "schema_name" {
  type = string
  description = "The name of the schema/database"
}

variable "schema_comment" {
  type = string
  default = "default schema comment"
}

variable "warehouse_id" {
  type = string
  default = "warehouse id to use to create the tables"
}

variable "tables" {
  type = map(object({
    comment = optional(string, "Default table comment")
    columns = list(object({
      name = string
      type = string
      comment = optional(string)
    }))
  }))
  description = "A map of table definitions with their respective columns"
}