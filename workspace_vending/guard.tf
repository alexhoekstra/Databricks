# ==============================================================================
# guard.tf 
# ==============================================================================

resource "terraform_data" "workspace_guard" {
  input = keys(var.workspaces)

  lifecycle {
    precondition {
      condition = length(distinct([
        for ws in local.workspaces_effective : ws.root_bucket_name
      ])) == length(var.workspaces)
      error_message = "Every workspace's effective root_bucket_name must be unique (S3 bucket names are global)."
    }

    precondition {
      condition = length(distinct(compact([
        for ws in var.workspaces : ws.deployment_name
      ]))) == length(compact([for ws in var.workspaces : ws.deployment_name]))
      error_message = "Every non-null deployment_name must be unique (it becomes the workspace URL)."
    }

    precondition {
      condition = length(flatten([
        for ws in var.workspaces : ws.network.private_subnet_ids
        ])) == length(distinct(flatten([
          for ws in var.workspaces : ws.network.private_subnet_ids
      ])))
      error_message = "A subnet cannot be shared between workspaces — Databricks requires dedicated subnets per workspace."
    }

    precondition {
      condition = alltrue([
        for ws in local.workspaces_effective : ws.region == var.aws_region
      ])
      error_message = "All workspaces must use var.aws_region for now: one aws provider creates the root buckets. Multi-region vending needs an aws provider alias per region."
    }
  }
}
