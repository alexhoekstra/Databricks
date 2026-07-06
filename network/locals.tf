# ==============================================================================
# locals.tf
# Peering wiring. Map keys derive only from config (peering keys,
# allow-list indexes, range(az_count))
# ==============================================================================

locals {
  vpcs_effective = {
    for key, v in var.vpcs : key => {
      cidr     = v.cidr
      az_count = v.az_count
    }
  }

  # One route per (peering, direction, private route table index): each side's
  # private route tables get a route to the other side's CIDR.
  peering_routes = merge(
    {
      for pair in flatten([
        for pk, p in var.peerings : [
          for i in range(local.vpcs_effective[p.requester].az_count) : {
            key         = "${pk}-req-${i}"
            peering_key = pk
            vpc         = p.requester
            rt_index    = i
            dest_cidr   = local.vpcs_effective[p.accepter].cidr
          }
        ]
      ]) : pair.key => pair
    },
    {
      for pair in flatten([
        for pk, p in var.peerings : [
          for i in range(local.vpcs_effective[p.accepter].az_count) : {
            key         = "${pk}-acc-${i}"
            peering_key = pk
            vpc         = p.accepter
            rt_index    = i
            dest_cidr   = local.vpcs_effective[p.requester].cidr
          }
        ]
      ]) : pair.key => pair
    }
  )

  # One ingress rule per (peering, allow entry), landing on the ingress_side
  # VPC's chosen SG with the other side's CIDR as source.
  peering_sg_rules = {
    for pair in flatten([
      for pk, p in var.peerings : [
        for i, rule in p.allow : {
          key         = "${pk}-${i}"
          vpc         = rule.ingress_side == "requester" ? p.requester : p.accepter
          source_cidr = local.vpcs_effective[rule.ingress_side == "requester" ? p.accepter : p.requester].cidr
          target_sg   = rule.target_sg
          protocol    = rule.protocol
          from_port   = rule.from_port
          to_port     = rule.to_port
          description = rule.description
        }
      ]
    ]) : pair.key => pair
  }
}
