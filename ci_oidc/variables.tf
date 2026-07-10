variable "github_repo" {
  description = "GitHub repository whose Actions jobs may assume the role."
  type        = string
  default     = "alexhoekstra/Databricks"
}

variable "aws_region" {
  description = "AWS region for the provider."
  type        = string
  default     = "us-east-2"
}

variable "state_bucket" {
  description = "Existing S3 bucket holding Terraform remote state."
  type        = string
  default     = "alexh-tf-state-7b7c8757"
}

variable "state_key_prefixes" {
  description = "State key prefixes the CI role may read/write."
  type        = list(string)
  default     = ["declarative_bronze"]
}
