# module: source_ingest

**Unity Catalog governance** for the `declarative_bronze` project.

Creates:
- `databricks_storage_credential` — IAM-role-backed S3 access.
- `databricks_external_location` — registers `source_path`. Every table reads under it and is routed by filename.
- Optional grants (`READ_FILES`, `CREATE_EXTERNAL_TABLE`) when `grantee` is set.

Takes `source_path` (resolved s3 URI) as an input — the root computes it from
`var.source_domain` and passes it both here and into the pipeline config, keeping
a single source of truth and the generated pipeline file independent of these
resources.
