# lakeflow_connect — RDS → Databricks CDC Pipeline (Terraform)

A full-stack change data capture (CDC) pipeline from an AWS RDS MySQL database
into Databricks Unity Catalog, provisioned end-to-end with Terraform. It covers
the whole stack: source database, replication, storage, IAM, and the Databricks
ingestion job.

> **On the name:** the goal was to use [Databricks Lakeflow
> Connect](https://docs.databricks.com/aws/en/ingestion/lakeflow-connect/), but
> the managed connectors for MySQL are in preview and unavailable on the free
> tier. This implementation instead lands DMS CDC output as Parquet in S3 and
> ingests it with Auto Loader.

## Architecture

```
RDS MySQL (source)
    └── AWS DMS (full load + CDC via binlog)
          └── S3 (Parquet files, partitioned by date)
                └── Databricks Auto Loader (streaming ingest)
                      └── Bronze Delta tables (Unity Catalog)

RDS MySQL ──── Lakehouse Federation ────► rds_foreign catalog (live query, no ETL)
```

## Two-layer split

The pipeline is split into two **independent** Terraform root modules so each
can be planned and applied on its own:

| Layer | Directory | Provisions | Needs |
|-------|-----------|------------|-------|
| AWS | [`aws/`](aws/) | RDS, DMS, S3, IAM | AWS credentials |
| Databricks | [`databricks/`](databricks/) | Unity Catalog, jobs | `DATABRICKS_HOST` / `DATABRICKS_TOKEN` |

The **AWS layer** declares no Databricks resources and needs no Databricks
token. The **Databricks layer** declares no AWS resources and makes no AWS API
calls — it reads every AWS value it needs (S3 bucket, IAM role, RDS endpoint and
credentials) from the AWS layer's state via `terraform_remote_state` (local
backend, sibling state file):

```hcl
data "terraform_remote_state" "aws" {
  backend = "local"
  config  = { path = "../aws/terraform.tfstate" }
}
```

This is the only coupling between the layers. The RDS password is exported once
as a **sensitive** output from the AWS layer and consumed through remote state,
so it is never duplicated.

See each layer's README for full detail:
- [`aws/README.md`](aws/README.md)
- [`databricks/README.md`](databricks/README.md)

## Deploy

**Apply order:** AWS first (its state file must exist for the Databricks layer to
read), then Databricks.

```bash
# 1. AWS layer
cd aws
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform init
terraform apply

# 2. Databricks layer
cd ../databricks
terraform init
terraform apply
```

`terraform.tfvars` is gitignored — never commit it. The Databricks layer needs
no `terraform.tfvars` (its only variable has a default; all AWS/RDS values come
from remote state).

### Post-apply

```bash
# Start the DMS replication task (Terraform provisions but does not start it)
# Its not started because it costs ~$30 a month to keep running so we only turn
# it on when we are using it
cd aws
aws dms start-replication-task \
  --replication-task-arn $(terraform output -raw dms_task_arn) \
  --start-replication-task-type start-replication

# Trigger the ingestion job manually or use the Databricks UI
cd ../databricks
databricks jobs run-now --job-id $(terraform output -raw ingestion_job_id)
```

## Directory layout

```
lakeflow_connect/
├── aws/              — AWS layer (RDS, DMS, S3, IAM) + outputs consumed by databricks/
├── databricks/       — Databricks layer (Unity Catalog, jobs); reads ../aws state
│   └── config/
│       └── autoloader_cdc_bronze.py   — Auto Loader notebook (uploaded by Terraform)
└── migrate_state.sh  — one-time split of the old combined state
```

## Cost notes

Running continuously this stack costs roughly **$30–40/month** (RDS t4g.micro
~$15, DMS t3.small ~$30). Stop both between sessions:

```bash
cd aws
# Stop DMS task
aws dms stop-replication-task --replication-task-arn $(terraform output -raw dms_task_arn)
# Stop RDS (uncomment aws_rds_instance_state in rds.tf)
```
