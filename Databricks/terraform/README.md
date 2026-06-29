# Terraform

This repository holds the terraform scripts I utilized. Please look at the [`lakeflow_connect`](lakeflow_connect/) folder more the most complete example

## Contents

- [:heart:`lakeflow_connect`](lakeflow_connect/) — RDS → DMS → S3 → Databricks CDC pipeline, split into two Terraform layers:
  - [`lakeflow_connect/aws`](lakeflow_connect/aws/) — **AWS layer** (RDS, DMS, S3, IAM). Apply first.
  - [`lakeflow_connect/databricks`](lakeflow_connect/databricks/) — **Databricks layer** (Unity Catalog, jobs). Reads the AWS layer's outputs via remote state.
- [`scalable_ingestion`](scalable_ingestion/) — Configuration-driven scalable ingestion pipeline for Unity Catalog bronze tables
- [`modules`](/modules) - Reusable modules for terraform scripts
- [`dev`](/dev) - Various testing and learning scripts

## CDC pipeline: two-layer split

The CDC pipeline is split into two independent Terraform root modules so each
can be applied on its own:

| Layer | Directory | Provisions | Needs |
|-------|-----------|------------|-------|
| AWS | [`lakeflow_connect/aws/`](lakeflow_connect/aws/) | RDS, DMS, S3, IAM | AWS credentials |
| Databricks | [`lakeflow_connect/databricks/`](lakeflow_connect/databricks/) | Unity Catalog, jobs | `DATABRICKS_HOST` / `DATABRICKS_TOKEN` |

**Apply order:** `aws` first, then `databricks`. The Databricks layer reads
`../aws/terraform.tfstate` via `terraform_remote_state` (local backend) and
creates no AWS infrastructure of its own.

```bash
cd lakeflow_connect/aws && terraform init && terraform apply
cd ../databricks        && terraform init && terraform apply
```