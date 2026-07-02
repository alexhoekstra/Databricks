# ==============================================================================
# pipeline.tf
# ==============================================================================

locals {
  domain_path = "s3://${var.source_domain.bucket}"
  domain_format = var.source_domain.format
}

resource "local_file" "pipeline" {
  filename = "${path.root}/${var.bundle_resources_dir}/pipeline.gen.yml"

  content = templatefile("${path.module}/templates/pipeline.yml.tftpl", {
    target_catalog = var.target_catalog
    target_schema  = var.target_schema
    continuous     = var.continuous
    domain_path    = local.domain_path
    domain_format  = local.domain_format
  })
}
