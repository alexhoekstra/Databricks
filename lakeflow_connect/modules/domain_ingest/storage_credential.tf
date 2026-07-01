# ==============================================================================
# storage_credential.tf
# Per-domain UC storage credential. The auth block is cloud-specific and chosen
# by source_infrastructure.type via a dynamic block — add azure_managed_identity
# / GCP variants here to support new clouds.
#
# The referenced IAM role is pre-existing (created by the domain's landing infra,
# e.g. the aws/ example). Its trust must already be self-assuming, so the
# credential validates immediately. See aws/iam.tf in the worked example.
# ==============================================================================

resource "databricks_storage_credential" "this" {
  name    = local.credential_name
  comment = "Managed by Terraform — ${var.domain} (${local.infra.type})"

  dynamic "aws_iam_role" {
    for_each = local.infra.type == "aws" ? [1] : []
    content {
      role_arn = local.infra.role_arn
    }
  }
}

resource "databricks_grants" "credential" {
  storage_credential = databricks_storage_credential.this.id

  grant {
    principal  = var.grantee
    privileges = ["CREATE_EXTERNAL_TABLE", "READ_FILES", "WRITE_FILES"]
  }
}
