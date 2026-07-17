# modules/domain_ingest

Per-domain module: provisions the Unity Catalog governance for a domain
and generates the Databricks Asset Bundle resource file that deploys its bronze
schema, checkpoint volume, and ingestion job. 

## What it creates

| File | Resource | Purpose |
|------|----------|---------|
| `storage_credential.tf` | `databricks_storage_credential` + grant | Per-domain UC credential. The IAM role must pre-exist with the required permissions |
| `external_location.tf` | `databricks_external_location` + grant | Registers the domain's storage root for reading source data.|
| `federation.tf` | `databricks_connection` + `databricks_catalog` + grant | Optional Lakehouse Federation — created only when `var.federation` is set |
| `bundle_job.tf` & `templates/job.yml.tftpl` | `local_file` | creates `<domain>.gen.yml` into the bundle's `resources/`, containing the bronze schema + checkpoint volume + `python_wheel_task` job |


## Naming (`locals.tf`)

`target_schema = "<domain>_bronze"`; credential / location / connection / catalog
names are derived from `var.domain`.
