# ==============================================================================
# variables.tf
# ==============================================================================

variable "aws_region" {
  description = "AWS region for all VPCs."
  type        = string
  default     = "us-east-2"
}

variable "resource_prefix" {
  description = "Prefix seeding all resource names."
  type        = string
  default     = "dbx-net"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.resource_prefix))
    error_message = "resource_prefix must be lowercase alphanumeric/hyphens."
  }
}

variable "create_dms_vpc_role" {
  description = <<-EOT
    Create the account-level IAM role named exactly `dms-vpc-role` that AWS
    requires before CreateReplicationSubnetGroup. Set false if that root is currently applied in this
    account (EntityAlreadyExists otherwise).
  EOT
  type        = bool
  default     = true
}

variable "vpcs" {
  description = <<-EOT
    Map of VPC key -> configuration. The single source of truth for which VPCs
    exist: adding a VPC = adding one entry here. Each entry becomes one
    modules/databricks_vpc instance
  EOT

  type = map(object({
    cidr                        = string                # netmask /16../22 (subnets = +4 newbits -> within Databricks /17../26)
    az_count                    = optional(number, 2)   # >= 2 (Databricks requirement)
    enable_databricks_endpoints = optional(bool, true)  # S3 gateway + STS/Kinesis interface trio
    create_dms_subnet_group     = optional(bool, false) # DMS wiring (subnet group + SG), no instance
    nat_per_az                  = optional(bool, false) # single NAT (demo) vs per-AZ (prod HA)
    tags                        = optional(map(string), {})
  }))
}

variable "peerings" {
  description = <<-EOT
    Map of peering key -> connection between two VPCs declared in var.vpcs.
    Each entry creates the peering connection, routes into both sides' private
    route tables, and the `allow` ingress rules:
      - ingress_side: which side's SG receives the rule ("requester"/"accepter");
        the source CIDR is always the other side's VPC CIDR
      - target_sg: "primary" = that VPC's Databricks SG, "dms" = its DMS SG
        (requires create_dms_subnet_group = true on that side — see guard.tf)
  EOT

  type = map(object({
    requester = string
    accepter  = string
    allow = optional(list(object({
      description  = string
      protocol     = optional(string, "tcp")
      from_port    = number
      to_port      = number
      ingress_side = string
      target_sg    = optional(string, "primary")
    })), [])
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for p in var.peerings : [
        for rule in p.allow :
        contains(["requester", "accepter"], rule.ingress_side) && contains(["primary", "dms"], rule.target_sg)
      ]
    ]))
    error_message = "allow rules: ingress_side must be \"requester\" or \"accepter\"; target_sg must be \"primary\" or \"dms\"."
  }
}
