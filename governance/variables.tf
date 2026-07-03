# ==============================================================================
# variables.tf
# ==============================================================================

variable "catalogs" {
  description = "Existing UI-created catalogs and the schemas Terraform manages inside them."
  type = map(object({
    schemas = map(object({
      comment = optional(string, "")
    }))
  }))
}

variable "service_principals" {
  description = "Automation identities: display-name key -> the teams (group keys) it joins."
  type = map(object({
    teams = optional(list(string), [])
  }))
  default = {}
}
