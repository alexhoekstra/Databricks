# ingestion/ — per-domain UC governance

The configuration-driven entry point for the `lakeflow_connect` pipeline. It
instantiates one [`../modules/domain_ingest`](../modules/domain_ingest) per
domain via `for_each = var.domains` and gnerates the DAB job
resource files the bundle deploys.

## Single Source of Truth - Configuration Driven Ingestion

`terraform.tfvars` holds the `domains` map — the one place that defines which
domains exist and how each is ingested.

Each entry (see `variables.tf` for the full shape):

| Field | Required | Notes |
|-------|----------|-------|
| `source_infrastructure` | yes | `{ type = "aws", role_arn, bucket, prefix }` — pre-existing landing infra. Only `type = "aws"` so far for this example |
| `source_schema` | yes | Source DB/schema name (lineage + job params) |
| `target_catalog` | no | UC catalog for the bronze schema (default `main`) |
| `grantee` | yes | Principal granted UC access;
| `schedule` | no | Quartz cron for the job (default `0 0 6 * * ?`) |
| `federation` | no | `{ connection_type, host, port, user, password }` — only for queryable DB sources (Lakeflow Federation) |

## Outputs

`terraform output domains` — a per-domain summary: storage credential, external
location (+ url), federated catalog (or null), bronze schema, resolved source
path, and the path of the generated job resource file.

## Adding a domain

Add an entry to `domains` in `terraform.tfvars`, then `terraform apply` +
`databricks bundle deploy`. No new HCL to write — the module and bundle are
already generic. What the module creates per domain is documented in
[`../modules/domain_ingest`](../modules/domain_ingest/README.md).
