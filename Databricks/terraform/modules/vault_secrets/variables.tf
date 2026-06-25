variable "mount" {
  description = "Vault KV engine mount path"
  type        = string
  default     = "kv"
}

variable "secret_name" {
  description = "Vault KV secret path name"
  type        = string
}
