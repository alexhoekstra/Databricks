# ==============================================================================
# locals.tf  (workspace module)
# ==============================================================================

locals {
  role_name = "${var.resource_prefix}-${var.workspace_key}-crossaccount"

  # Unlike the UC storage-credential roles elsewhere in the repo, the
  # workspace credentials role needs no SelfAssume statement — so there's no
  # role->policy->role cycle and aws_iam_role.cross_account.arn can be
  # referenced directly. No constructed-ARN local needed.
}
