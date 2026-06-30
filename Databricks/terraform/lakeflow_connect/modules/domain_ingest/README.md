# modules/domain_ingest — one external source system

Per-domain module: provisions the Unity Catalog governance for a single domain
and generates the Databricks Asset Bundle resource file that deploys its bronze
schema, checkpoint volume, and ingestion job. Instantiated once per domain by the
[`../../ingestion`](../../ingestion) root; the caller passes in a configured
`databricks` provider (this module configures none).

## What it creates

| File | Resource | Purpose |
|------|----------|---------|
| `storage_credential.tf` | `databricks_storage_credential` + grant | Per-domain UC credential; cloud-specific auth via a `dynamic` block keyed on `source_infrastructure.type` (only `aws_iam_role` today). The IAM role is pre-existing |
| `external_location.tf` | `databricks_external_location` + grant | Registers the domain's storage root for **reading source data**. Checkpoints are *not* here, so the source bucket can be read-only |
| `federation.tf` | `databricks_connection` + `databricks_catalog` + grant | **Optional** Lakehouse Federation (foreign catalog) — created only when `var.federation` is set (queryable DB sources) |
| `bundle_job.tf` → `templates/job.yml.tftpl` | `local_file` | The **TF → DAB bridge**: renders `<domain>.gen.yml` into the bundle's `resources/`, containing the bronze **schema + checkpoint volume + `python_wheel_task` job** |

## Key inputs (`variables.tf`)

`domain`, `source_infrastructure` (`type` + aws `role_arn`/`bucket`/`prefix`),
`source_schema`, `target_catalog` (default `main`), `grantee`, `enable_federation`
+ `federation`, `schedule`, plus two path defaults: `bundle_resources_dir`
(where the `*.gen.yml` is written) and `wheel_dependency` (the built wheel glob).

## Outputs (`outputs.tf`)

`storage_credential_name`, `external_location_name` / `_url`, `foreign_catalog`
(null when federation is off), `bronze_schema`, `source_path`, and
`job_resource_file`.

## Naming (`locals.tf`)

`target_schema = "<domain>_bronze"`; credential / location / connection / catalog
names are derived from `var.domain`.

## Behaviors worth knowing

- **The schema, checkpoint volume, and job are DAB-owned** (they live in the
  generated file, not in Terraform state). In a `development` bundle target their
  names are **prefixed** per user (e.g. `dev_<user>_hr_bronze`).
- To stay correct under that prefixing, the generated job passes `target_schema`
  and `checkpoint_base` as DAB references — `${resources.schemas.…name}` and
  `/Volumes/<catalog>/${resources.schemas.…name}/${resources.volumes.…name}` — so
  they always resolve to the actually-deployed names in dev and prod.
- **Checkpoints + inferred schema live in a UC managed volume** (`_checkpoints`)
  under the bronze schema, so stream state needs no write access to the source
  bucket. The volume name is an implicit contract with the wheel's default in
  [`cdc_bronze_ingest/config.py`](../../bundles/lakeflow_connect/cdc_bronze_ingest/src/cdc_bronze_ingest/config.py)
  (`DEFAULT_CHECKPOINT_VOLUME`).

## Cloud-pluggable

`source_infrastructure.type` is the discriminator. Adding `azure`/`gcp` later =
one new auth block in `storage_credential.tf` + one entry in the `storage_root` /
`source_path` maps in `locals.tf`. The domain interface and the DAB stay unchanged.
