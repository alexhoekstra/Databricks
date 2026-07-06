# ==============================================================================
# iam.tf
# Cross-account credentials role the Databricks control plane assumes to run
# workspace compute in the AWS account.
# ==============================================================================

data "databricks_aws_assume_role_policy" "this" {
  external_id = var.databricks_account_id
}

data "databricks_aws_crossaccount_policy" "this" {
  policy_type = "managed"
}

resource "aws_iam_role" "cross_account" {
  name               = local.role_name
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json
  description        = "Databricks cross-account credentials role for workspace ${var.workspace_name}"
}

resource "aws_iam_role_policy" "cross_account" {
  name   = "${local.role_name}-policy"
  role   = aws_iam_role.cross_account.id
  policy = data.databricks_aws_crossaccount_policy.this.json
}
resource "time_sleep" "iam_propagation" {
  create_duration = "20s"

  depends_on = [aws_iam_role_policy.cross_account]
}
