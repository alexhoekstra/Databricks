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

variable "sp" {
  type = string
  description = "The Display name of the service principal to use"
  default = null
}

variable "wheel_version" {
  type    = string
  default = "0.1.0"
}