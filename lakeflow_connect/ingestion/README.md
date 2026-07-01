# ingestion/ — per-domain UC governance (Terraform root)

The configuration-driven entry point for the `lakeflow_connect` pipeline. It
instantiates one [`../modules/domain_ingest`](../modules/domain_ingest) per
domain via `for_each = var.domains` and, as a side effect, generates the DAB job
resource files the bundle deploys.

each domain's landing infra is assumed to already exist (see [`../aws`](../aws)
for a worked example). It authenticates to Databricks from environment variables
but can just as easily be converted to use a secrets manaager (e.g. Vault)

```bash
export DATABRICKS_HOST=https://your-workspace.cloud.databricks.com
export DATABRICKS_TOKEN=dapi...
```

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

## Apply order

```bash
terraform init
terraform apply        # creates UC governance + writes ../bundles/lakeflow_connect/resources/<domain>.gen.yml
cd ../bundles/lakeflow_connect && databricks bundle deploy -t dev
```

**Terraform first, then the bundle** — the bundle deploys the `*.gen.yml` files
this root generates.

## Adding a domain

Add an entry to `domains` in `terraform.tfvars`, then `terraform apply` +
`databricks bundle deploy`. No new HCL to write — the module and bundle are
already generic. What the module creates per domain is documented in
[`../modules/domain_ingest`](../modules/domain_ingest/README.md).
