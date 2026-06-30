# CDC Pipeline — AWS layer (Terraform)

The **AWS infrastructure layer** of the CDC pipeline. It provisions the source
database, replication, storage, and IAM — everything that lives in AWS. It
declares no Databricks resources and requires no Databricks credentials, so it
can be applied entirely on its own.

This is a **standalone worked example** — one way to stand up a domain's landing
infrastructure end-to-end. It declares no Databricks resources. Its outputs
(`role_arn`, `bucket`, the RDS endpoint/credentials) are copied by hand into a
domain entry in [`../ingestion/terraform.tfvars`](../ingestion); there is no
`terraform_remote_state` coupling. Apply it standalone, whenever you need the
example infra.

## Architecture (AWS portion)

```
RDS MySQL (source)
    └── AWS DMS (full load + CDC via binlog)
          └── S3 (Parquet files, partitioned by date)

IAM: Databricks cross-account S3 role + 3 DMS service roles
```

## What gets provisioned

| Layer | Resource | Purpose |
|-------|----------|---------|
| **Source** | RDS MySQL 8.0 (`db.t4g.micro`) | Source database with binlog enabled for CDC [Databricks article](https://docs.databricks.com/aws/en/ingestion/lakeflow-connect/mysql-aws-rds-config) |
| **Replication** | DMS replication instance + task | Streams row changes (insert/update/delete) to S3 as Parquet |
| **Storage** | S3 bucket | Stores DMS CDC output (Parquet). Auto Loader checkpoints default to a UC managed volume, not this bucket |
| **IAM** | 4 IAM roles | DMS S3 write access, DMS VPC/CloudWatch roles, Databricks cross-account S3 access |

## Usage

### Prerequisites
- AWS CLI configured with appropriate permissions

### Deploy

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform init
terraform apply
```

`terraform.tfvars` is gitignored — never commit it.

### Start the DMS replication task

Terraform provisions the task but does not start it automatically:

```bash
aws dms start-replication-task \
  --replication-task-arn $(terraform output -raw dms_task_arn) \
  --start-replication-task-type start-replication
```

## Variables

| Variable | Description |
|----------|-------------|
| `databricks_account_id` | Databricks account UUID — Use your secrets management provider (e.g. Vault to inject this.  Terraform has a vault provider for this.)
| `db_password` | RDS MySQL admin password — Use your secrets management provider (e.g. Vault to inject this.  Terraform has a vault provider for this.)

## Values used by the ingestion root

Copy these into the matching domain entry in `../ingestion/terraform.tfvars`
(no remote state is read):

| Output | Goes into (domain entry) |
|--------|--------------------------|
| `databricks_role_arn` | `source_infrastructure.role_arn` (UC storage credential) |
| `s3_bucket_name` | `source_infrastructure.bucket` (UC external location + source path) |
| `db_address` / `db_port` / `db_username` / `db_password` / `db_name` | the optional `federation` block (UC MySQL connection) |

`db_password` is exported as a **sensitive** output; keep `terraform.tfvars`
gitignored on both sides. Ideally you would use a Secrets manager for this like vault.

## File layout

```
main.tf     — providers (aws, time), variables, data sources
rds.tf      — security group, RDS instance, S3 bucket
iam.tf      — all IAM roles and policies
dms.tf      — DMS replication instance, endpoints, task
outputs.tf  — useful ARNs + values consumed by the Databricks layer
```

## Cost notes

Running continuously this layer costs roughly **$30–40/month** (RDS t4g.micro
~$15, DMS t3.small ~$30). Stop both between sessions if trying to manage free tier usage:

```bash
# Stop DMS task
aws dms stop-replication-task --replication-task-arn $(terraform output -raw dms_task_arn)

# Stop RDS (uncomment aws_rds_instance_state in rds.tf)
```
