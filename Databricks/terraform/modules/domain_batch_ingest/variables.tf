variable "domain" {
  type = string
  description = "The name of the domain"
  default = null
}

variable "source_type" {
  type = string
  description = "The name of the source (kaggle, huggingface, etc.)"
  default = null
}

variable "source_config" {
  type = string
  description = "JSON blob configuration details"
  default = null
}

variable "target_table" {
  type = string
  description = "The name of target table in the bronze schema"
  default = null
}

variable "schedule" {
  type = string
  description = "The quartz cron expression for the schedule of the job"
  default = null
}

variable "target_catalog" {
  type = string
  description = "The name of target catalog"
  default = null
}