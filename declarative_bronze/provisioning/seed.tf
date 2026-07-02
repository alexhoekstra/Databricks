# ==============================================================================
# seed.tf
# ==============================================================================

variable "seed_enabled" {
  description = "Upload the bundled sample files so the pipeline has data on first run."
  type        = bool
  default     = true
}

variable "seed_date" {
  description = "Dated folder the seed drops into (models a daily batch)."
  type        = string
  default     = "2026-07-01"
}

locals {
  # Tables to seed are inferred from the Parquet files bundled in seed/ — the file
  # name is the table it feeds, so there's no list to keep in sync. each.value is
  # the filename (e.g. "programs.parquet").
  seed_files = var.seed_enabled ? fileset("${path.module}/seed", "*.parquet") : toset([])
}

resource "aws_s3_object" "seed" {
  for_each = local.seed_files

  bucket = aws_s3_bucket.landing.id
  key    = "${var.seed_date}/${each.value}"
  source = "${path.module}/seed/${each.value}"
  etag   = filemd5("${path.module}/seed/${each.value}") # re-upload when the file changes
}
