# locals.tf

locals {
  infra = var.source_infrastructure

  # Root URI registered as the external location 
  storage_root = {
    aws = "s3://${try(local.infra.bucket, "")}"
  }[local.infra.type]

  # Where the source data lands.
  source_path = {
    aws = "s3://${try(local.infra.bucket, "")}/${trim(try(local.infra.prefix, ""), "/")}"
  }[local.infra.type]

  target_schema   = "${var.domain}_bronze"
  credential_name = "${var.domain}-storage-credential"
  location_name   = "${var.domain}-external-location"
  connection_name = "${var.domain}-connection"
  catalog_name    = "${var.domain}_federated"

  federation_enabled = var.enable_federation
}
