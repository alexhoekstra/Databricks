# ==============================================================================
# variables.tf
# ==============================================================================

variable "name" {
  description = "Short name for this VPC (the var.vpcs map key at the root). Seeds resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.name))
    error_message = "name must be lowercase alphanumeric/hyphens."
  }
}

variable "resource_prefix" {
  description = "Prefix for all resource names created by this module."
  type        = string
}

variable "cidr" {
  description = <<-EOT
    VPC CIDR. Netmask must be /16../22: subnets are carved with newbits = 4
    (e.g. /20 VPC -> /24 subnets), which keeps every subnet inside Databricks'
    required /17../26 range.
  EOT
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "cidr must be a valid IPv4 CIDR block."
  }

  validation {
    condition = (
      can(cidrhost(var.cidr, 0)) &&
      tonumber(split("/", var.cidr)[1]) >= 16 &&
      tonumber(split("/", var.cidr)[1]) <= 22
    )
    error_message = "cidr netmask must be between /16 and /22 so the +4-newbits subnets stay within Databricks' /17../26 subnet requirement."
  }
}

variable "az_count" {
  description = "Number of availability zones."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "Databricks requires subnets in at least 2 availability zones."
  }
}

variable "enable_databricks_endpoints" {
  description = "Create the standard Databricks endpoint trio: S3 gateway + STS/Kinesis interface endpoints. Enable on VPCs that run Databricks clusters."
  type        = bool
  default     = true
}

variable "create_dms_subnet_group" {
  description = "Create a DMS replication subnet group + DMS security group in this VPC. Requires the account-level dms-vpc-role to exist first."
  type        = bool
  default     = false
}

variable "nat_per_az" {
  description = "One NAT gateway per AZ instead of a single shared one. Route tables are per-AZ either way, so flipping this only changes routes."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags merged onto this VPC's resources."
  type        = map(string)
  default     = {}
}
