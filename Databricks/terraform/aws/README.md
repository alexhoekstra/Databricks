# Databricks CDC Pipeline — AWS / Terraform

Terraform project that provisions a complete change data capture (CDC) pipeline from an AWS RDS MySQL database into Databricks Unity Catalog. It covers the full stack: source database, replication, storage, IAM, and the Databricks ingestion job.

I plan to continue to update this to make it more scalable and configuration and metadata driven as time permits.

## Architecture

```
RDS MySQL (source)
    └── AWS DMS (full load + CDC via binlog)
          └── S3 (Parquet files, partitioned by date)
                └── Databricks Auto Loader (streaming ingest)
                      └── Bronze Delta tables (Unity Catalog)

RDS MySQL ──── Lakehouse Federation ────► rds_foreign catalog (live query, no ETL)
```

## What gets provisioned

| Layer | Resource | Purpose |
|-------|----------|---------|
| **Source** | RDS MySQL 8.0 (`db.t4g.micro`) | Source database with binlog enabled for CDC |
| **Replication** | DMS replication instance + task | Streams row changes (insert/update/delete) to S3 as Parquet |
| **Storage** | S3 bucket | Stores DMS CDC output and Auto Loader checkpoints |
| **IAM** | 4 IAM roles | DMS S3 write access, DMS VPC/CloudWatch roles, Databricks cross-account S3 access |
| **Databricks** | Storage credential + external location | Registers S3 bucket in Unity Catalog via IAM role |
| **Databricks** | Foreign catalog (`rds_foreign`) | Lakehouse Federation — query MySQL live without ETL |
| **Databricks** | Bronze schema + Auto Loader notebook | Appends CDC events to Delta tables, scheduled daily at 6 AM ET |

## Usage

### Prerequisites
- AWS CLI configured with appropriate permissions
- Databricks workspace with Unity Catalog enabled
- `DATABRICKS_HOST` and `DATABRICKS_TOKEN` environment variables set

### Deploy

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform init
terraform apply
```

`terraform.tfvars` is gitignored — never commit it.

> **First apply note:** `iam.tf` contains a `SelfAssume` trust statement in the Databricks IAM role that must be commented out on the first `apply`, then uncommented and re-applied after the role exists. See the comment in `iam.tf` for details.

### Start the DMS replication task

Terraform provisions the task but does not start it automatically:

```bash
aws dms start-replication-task \
  --replication-task-arn $(terraform output -raw dms_task_arn) \
  --start-replication-task-type start-replication
```

### Trigger the ingestion job manually

```bash
databricks jobs run-now --job-id $(terraform output -raw ingestion_job_id)
```

### Query live MySQL data (no ETL)

```sql
SELECT * FROM rds_foreign.mydb.<table>
```

## Variables

| Variable | Description |
|----------|-------------|
| `databricks_account_id` | Databricks account UUID (used as STS ExternalId) |
| `databricks_user_email` | Databricks user granted UC privileges |
| `db_password` | RDS MySQL admin password — pass via `terraform.tfvars` or `TF_VAR_db_password` |

## File layout

```
main.tf          — providers, variables, data sources
rds.tf           — security group, RDS instance, S3 bucket
iam.tf           — all IAM roles and policies
dms.tf           — DMS replication instance, endpoints, task
databricks.tf    — Unity Catalog resources and ingestion job
outputs.tf       — useful ARNs and identifiers post-apply
config/
  autoloader_cdc_bronze.py — Auto Loader notebook (uploaded to workspace by Terraform)
```

## Cost notes

Running continuously this stack costs roughly **$30–40/month** (RDS t4g.micro ~$15, DMS t3.small ~$30). Stop both between sessions:

```bash
# Stop DMS task
aws dms stop-replication-task --replication-task-arn $(terraform output -raw dms_task_arn)

# Stop RDS (uncomment aws_rds_instance_state in rds.tf)
```
