# CDC Pipeline — Databricks layer (Terraform)

This was built up from the Documentation available on Databricks. I wanted to use Lakeflow Connect, however the Managed Connectors for MySQL are in preview and not available to free tier users. Instead, this implementation uses Auto Loader with S3 Parquet files as the data source. <small>[Reference](https://docs.databricks.com/aws/en/ingestion/cloud-object-storage/onboard-data?language=Python)</small>


The **Databricks infrastructure layer** of the CDC pipeline. It provisions only
Unity Catalog and job resources. It declares **no AWS resources** and makes no
AWS API calls — every AWS value it needs (S3 bucket, IAM role, RDS endpoint and
credentials) is read from the AWS layer's state via `terraform_remote_state`.

The AWS layer lives in [`../aws`](../aws) and **must be applied first** so its
state file (`../aws/terraform.tfstate`) exists for this layer to read.

## Architecture (Databricks portion)

```
S3 (DMS Parquet) ──► Databricks Auto Loader ──► Bronze Delta tables (Unity Catalog)

RDS MySQL ──── Lakehouse Federation ──► rds_foreign catalog (live query, no ETL)
```

## What gets provisioned

| Resource | Purpose |
|----------|---------|
| Storage credential + external location | Registers the S3 bucket in Unity Catalog via the IAM role from the AWS layer |
| Foreign catalog (`rds_foreign`) | Lakehouse Federation — query MySQL live without ETL |
| Bronze schema | Target schema for the append-only CDC bronze Delta tables |
| Workspace file (wheel) | Uploads the `cdc_bronze_ingest` wheel to the workspace |
| Job | Runs the wheel's `cdc_bronze_ingest` entry point on serverless compute, daily at 6 AM ET |

## Usage

### Prerequisites
- The AWS layer (`../aws`) already applied
- Databricks workspace with Unity Catalog enabled
- `DATABRICKS_HOST` and `DATABRICKS_TOKEN` environment variables set
- The `cdc_bronze_ingest` wheel built (this layer uploads the built artifact)

### Deploy

```bash
# 1. Build the ingestion wheel (only when its source changes)
cd ../../../notebooks/modules/cdc_bronze_ingest
python -m build --wheel

# 2. Apply this layer
cd -   # back to lakeflow_connect/databricks
terraform init
terraform apply
```

The wheel version is pinned in `main.tf` (`local.cdc_wheel_version`); bump it
there whenever the wheel's `pyproject.toml` version changes.

No `terraform.tfvars` is required — the only variable (`databricks_user_email`)
has a default, and all AWS/RDS values (including the RDS password) come from the
AWS layer's remote state.

### Trigger the ingestion job manually

```bash
databricks jobs run-now --job-id $(terraform output -raw ingestion_job_id)
```

### Query live MySQL data (no ETL)

```sql
SELECT * FROM rds_foreign.mydb.<table>
```

## How it reads the AWS layer

```hcl
data "terraform_remote_state" "aws" {
  backend = "local"
  config  = { path = "../aws/terraform.tfstate" }
}
```

Outputs are accessed through `local.aws.<output_name>` (see `main.tf`). This is
the only coupling between the layers — applying this layer never creates or
changes AWS infrastructure.

## Variables

| Variable | Description |
|----------|-------------|
| `databricks_user_email` | Databricks user granted UC privileges (has a default) |

## File layout

```
main.tf       — databricks provider, remote state, variables, locals (incl. wheel version)
databricks.tf — Unity Catalog resources, wheel upload, and ingestion job
outputs.tf    — catalog / schema / job identifiers
```

The ingestion logic lives in the `cdc_bronze_ingest` wheel at
[`../../../notebooks/modules/cdc_bronze_ingest`](../../../notebooks/modules/cdc_bronze_ingest);
this layer uploads the built wheel and runs its entry point as a job task.
