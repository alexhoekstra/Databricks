# variables.tf 

variable "domains" {
  description = <<-EOT
    Map of domain (external-system) name -> configuration. This is the single
    source of truth for which domains exist and how each is ingested.
  EOT

  type = map(object({
    source_infrastructure = object({
      type     = string
      role_arn = optional(string)
      bucket   = optional(string)
      prefix   = optional(string)
    })
    source_schema  = string
    target_catalog = optional(string, "main")
    grantee        = optional(string)
    schedule       = optional(string, "0 0 6 * * ?")
    federation = optional(object({
      connection_type = string
      host            = string
      port            = number
      user            = string
      password        = string
    }))
  }))
}