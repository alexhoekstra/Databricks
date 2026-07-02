# ==============================================================================
# variables.tf
# ==============================================================================

variable "source_name" {
  description = "Logical source name (key from the root sources map)."
  type        = string
}

variable "source_infrastructure" {
  description = "Cloud landing infra for this source."
  type = object({
    type     = string
    role_arn = optional(string)
    bucket   = optional(string)
    prefix   = optional(string)
  })
}

variable "source_path" {
  description = "Resolved storage URI for this source."
  type        = string
}

variable "grantee" {
  description = "Principal (user email or group) granted READ_FILES on the credential +external location."
  type        = string
  default     = null
}
