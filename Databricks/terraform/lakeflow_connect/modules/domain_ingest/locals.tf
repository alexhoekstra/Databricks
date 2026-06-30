# ==============================================================================
# locals.tf
# Cloud-specific values resolved from source_infrastructure.type, plus naming.
# To add a new infra type later: add a key to storage_root / source_path and a
# dynamic auth block in storage_credential.tf — nothing else changes.
# ==============================================================================

locals {
  infra = var.source_infrastructure

  # Root URI registered as the external location (covers the source data).
  # Per-type so future clouds use abfss:// / gs://.
  storage_root = {
    aws = "s3://${try(local.infra.bucket, "")}"
  }[local.infra.type]

  # Where the source data lands (passed to the job as --source_path).
  source_path = {
    aws = "s3://${try(local.infra.bucket, "")}/${trim(try(local.infra.prefix, ""), "/")}"
  }[local.infra.type]

  # Auto Loader checkpoints live in a UC managed volume under the bronze schema
  # (created as a DAB resource, path resolved in the job template) — not under
  # storage_root — so stream state needs no write access to the source bucket.

  # Naming
  target_schema   = "${var.domain}_bronze"
  credential_name = "${var.domain}-storage-credential"
  location_name   = "${var.domain}-external-location"
  connection_name = "${var.domain}-connection"
  catalog_name    = "${var.domain}_federated"

  federation_enabled = var.enable_federation
}
