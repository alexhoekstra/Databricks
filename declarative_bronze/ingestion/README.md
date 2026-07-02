# ingestion — UC governance + pipeline generation

The Terraform root for `declarative_bronze`. It owns **domain-level Unity Catalog
governance** and generates the Lakeflow Declarative Pipeline resource
that the DAB in [`../bundle`](../bundle) deploys.

`terraform.tfvars` is the single source of truth: it drives both the UC objects
and the generated pipeline config. The generated file depends only on `var.*`
(not on the Databricks resources), so it can be regenerated in CI without
Databricks auth.

## Key variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `source_domain` | — | Shared landing infra + file format for the whole domain (`type`, `role_arn`, `bucket`, `format`). |
| `target_catalog` | `main` | UC catalog for the bronze tables. |
| `target_schema` | `declarative_bronze` | Shared UC schema the pipeline writes into. |
| `continuous` | `false` | Run mode: `false` = triggered (quota-safe, auto-stops), `true` = always-on stream. |
| `grantee` | running identity | Principal for UC grants. |
| `bundle_resources_dir` | `../bundle/resources` | Where `pipeline.gen.yml` is written. |

## Notes
- **Adding a table** — drop `<table>.parquet` into the landing folder and re-run
  the pipeline; discovery picks it up. No config or code changes here.
