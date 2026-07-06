# ==============================================================================
# guard.tf
# ==============================================================================

resource "terraform_data" "network_guard" {
  input = keys(var.vpcs)

  lifecycle {
    precondition {
      condition = alltrue([
        for p in var.peerings :
        contains(keys(var.vpcs), p.requester) && contains(keys(var.vpcs), p.accepter) && p.requester != p.accepter
      ])
      error_message = "Every peering's requester/accepter must name two different keys declared in var.vpcs."
    }

    precondition {
      condition = length(distinct([
        for v in var.vpcs : v.cidr
      ])) == length(var.vpcs)
      error_message = "VPC CIDRs must be distinct (peered VPCs cannot overlap — AWS also rejects partial overlaps at apply)."
    }

    precondition {
      condition = length(distinct([
        for p in var.peerings : join("|", sort([p.requester, p.accepter]))
      ])) == length(var.peerings)
      error_message = "Only one peering per VPC pair — merge duplicate entries' allow lists."
    }

    precondition {
      condition = alltrue(flatten([
        for p in var.peerings : [
          for rule in p.allow :
          rule.target_sg != "dms" || var.vpcs[rule.ingress_side == "requester" ? p.requester : p.accepter].create_dms_subnet_group
        ]
      ]))
      error_message = "An allow rule with target_sg = \"dms\" needs create_dms_subnet_group = true on the ingress_side VPC (otherwise its DMS SG doesn't exist)."
    }
  }
}
