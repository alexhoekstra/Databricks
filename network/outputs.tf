# ==============================================================================
# outputs.tf  (network root)
# `vpcs` is the headline: shaped field-for-field like workspace_vending's
# var.workspaces[*].network
# ==============================================================================

output "vpcs" {
  description = "Per-VPC network object — exactly the shape workspace_vending's workspaces map consumes."
  value = {
    for name, mod in module.databricks_vpc : name => {
      vpc_id             = mod.vpc_id
      private_subnet_ids = mod.private_subnet_ids
      security_group_ids = mod.security_group_ids
    }
  }
}

output "network_details" {
  description = "Everything else, for evidence + debugging."
  value = {
    for name, mod in module.databricks_vpc : name => {
      vpc_cidr                        = mod.vpc_cidr
      public_subnet_ids               = mod.public_subnet_ids
      private_route_table_ids         = mod.private_route_table_ids
      nat_gateway_ids                 = mod.nat_gateway_ids
      endpoint_ids                    = mod.endpoint_ids
      dms_replication_subnet_group_id = mod.dms_replication_subnet_group_id
      dms_security_group_id           = mod.dms_security_group_id
    }
  }
}

output "peerings" {
  description = "Peering connection ids + acceptance status."
  value = {
    for name, p in aws_vpc_peering_connection.this : name => {
      id            = p.id
      accept_status = p.accept_status
    }
  }
}
