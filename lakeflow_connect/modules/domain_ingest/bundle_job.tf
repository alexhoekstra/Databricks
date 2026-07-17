# bundle_job.tf

# creates the per-domain ingestion job as a bundle resource file for the DAB from a template.
resource "local_file" "job" {
  filename = "${path.root}/${var.bundle_resources_dir}/${var.domain}.gen.yml"

  content = templatefile("${path.module}/templates/job.yml.tftpl", {
    domain          = var.domain
    job_resource    = "${var.domain}_cdc_ingest"
    job_name        = "${var.domain}-cdc-ingestion"
    source_path     = local.source_path
    source_schema   = var.source_schema
    target_catalog  = var.target_catalog
    target_schema   = local.target_schema
    schedule        = var.schedule
    wheel_glob      = var.wheel_dependency
  })
}
