# ==============================================================================
# mws.tf  (workspace module)
# The four account-level (mws_*) registrations: credentials, storage
# configuration, network, then the workspace that ties them together.
# ==============================================================================

resource "databricks_mws_credentials" "this" {
  # account_id is deprecated on this resource (comes from the provider block).
  credentials_name = "${var.resource_prefix}-${var.workspace_key}-creds"
  role_arn         = aws_iam_role.cross_account.arn

  depends_on = [time_sleep.iam_propagation]
}

resource "databricks_mws_storage_configurations" "this" {
  account_id                 = var.databricks_account_id
  storage_configuration_name = "${var.resource_prefix}-${var.workspace_key}-storage"
  bucket_name                = aws_s3_bucket.root.bucket

  depends_on = [aws_s3_bucket_policy.root]
}

resource "databricks_mws_networks" "this" {
  account_id         = var.databricks_account_id
  network_name       = "${var.resource_prefix}-${var.workspace_key}-network"
  vpc_id             = var.network.vpc_id
  subnet_ids         = var.network.private_subnet_ids
  security_group_ids = var.network.security_group_ids
}

resource "databricks_mws_workspaces" "this" {
  account_id     = var.databricks_account_id
  workspace_name = var.workspace_name
  aws_region     = var.region

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id

  # Both null-safe: null means "let the API pick".
  deployment_name = var.deployment_name
  pricing_tier    = var.pricing_tier

  custom_tags = var.custom_tags
}
