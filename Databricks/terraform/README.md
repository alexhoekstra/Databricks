# Terraform

This repository holds the terraform scripts I utilized. Please look at the [`lakeflow_connect`](lakeflow_connect/) folder for the most complete example.

## Contents

- [:heart:`lakeflow_connect`](lakeflow_connect/) — per-domain CDC ingestion into Unity Catalog bronze, split across Terraform + a Databricks Asset Bundle:
  - [`lakeflow_connect/ingestion`](lakeflow_connect/ingestion/) — **per-domain UC governance** (storage credential, external location, optional federation) via `for_each = var.domains`.
  - [`lakeflow_connect/modules/domain_ingest`](lakeflow_connect/modules/domain_ingest/) — the reusable per-domain module (cloud-pluggable `source_infrastructure`).
  - [`lakeflow_connect/aws`](lakeflow_connect/aws/) — a **single worked example** standing up one domain's landing infra (RDS/DMS/S3/IAM).
  - [`lakeflow_connect/bundles/lakeflow_connect`](lakeflow_connect/bundles/lakeflow_connect/) — the DAB that builds the `cdc_bronze_ingest` wheel (vendored inside it) + deploys each domain's bronze schema, checkpoint volume, and ingestion job.
- [`scalable_ingestion`](scalable_ingestion/) — Configuration-driven scalable ingestion pipeline for Unity Catalog bronze tables
- [`modules`](/modules) - Reusable modules for terraform scripts
- [`dev`](/dev) - Various testing and learning scripts

## CDC pipeline: Terraform + DAB, modular per domain

A "domain" is an external source system (HR, Finance, Business Development, …).
Terraform owns per-domain UC governance; the bundle owns the wheel + bronze
schema + checkpoint volume + ingestion job. Each domain's landing infra (bucket +
IAM role) is pre-existing — `aws/` is the worked example.

| Piece | Directory | Provisions | Needs |
|-------|-----------|------------|-------|
| UC governance | [`lakeflow_connect/ingestion/`](lakeflow_connect/ingestion/) | storage credential, external location, federation | `DATABRICKS_HOST` / `DATABRICKS_TOKEN` |
| Workload | [`lakeflow_connect/bundles/lakeflow_connect`](lakeflow_connect/bundles/lakeflow_connect/) | wheel, bronze schema, checkpoint volume, job | Databricks CLI + `uv` |
| Example infra | [`lakeflow_connect/aws/`](lakeflow_connect/aws/) | RDS, DMS, S3, IAM (one domain) | AWS credentials |

**Apply order:** Terraform `ingestion/` first (it generates the bundle's
per-domain resource files), then `databricks bundle deploy`.

```bash
cd lakeflow_connect/ingestion && terraform init && terraform apply
cd ../bundles/lakeflow_connect && databricks bundle deploy -t dev
```