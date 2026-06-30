# Databricks Platform Engineering Exploration

This repository contains elements and experiments from my journey as I learn about 
Databricks Platform Engineering. Below are the main areas of focus, each referencing a section of the codebase where more detailed
documentation can be found. The flagship example is the [`lakeflow_connect`](Databricks/terraform/lakeflow_connect/) full-stack AWS CDC pipeline.

### Musings

While Terraform can do many things, its core strength is managing workspace infrastructure. Declarative Automation Bundles (DABs) offer a more natural fit for orchestrating jobs, pipelines, and notebooks within Databricks. Used together, 
each handles what it does best.

>:heart: ***The [`lakeflow_connect`](Databricks/terraform/lakeflow_connect/) project is where that exploration comes together — a full-stack CDC pipeline from AWS RDS MySQL through DMS and S3 into Databricks Unity Catalog, with Lakehouse Federation for live querying, all provisioned end-to-end with Terraform.***
 
# Overview

## :heart: lakeflow_connect — AWS CDC Pipeline (Terraform + DAB)
The flagship project: a full-stack change data capture pipeline capturing row-level changes from an AWS RDS MySQL database through DMS and S3 into Databricks Unity Catalog bronze Delta tables via Auto Loader. (currently a triggred job, but updates can be made to make it streaming, Databricks Free Tier doesn't provide infrastructure to have constant streaming) It has an optional Lakehouse Federation foreign catalog for live querying without ETL. 

It splits the work across the two tools by what each does best — **Terraform** owns per-domain Unity Catalog governance (storage credential, external location, optional federation) while a **Declarative Automation Bundle** builds the `cdc_bronze_ingest` wheel and deploys each domain's bronze schema, checkpoint volume, and Auto Loader job.

Highlights:
- **Config-driven per domain** — the whole pipeline is declared in one `terraform.tfvars` `domains` map; adding a source system needs no new code.
- **Cloud-pluggable** — a `source_infrastructure.type` discriminator isolates the cloud-specific wiring (only `aws` today; `azure`/`gcp` slot in without changing the interface).
- **Read-only-source friendly** — Auto Loader checkpoints + inferred schema live in a UC managed volume under the bronze schema, so the source bucket needs no write access.
- **Reference:** [`Databricks/terraform/lakeflow_connect/`](Databricks/terraform/lakeflow_connect/)

## CI/CD — GitHub Actions
Automated deployment, dependency building, and testing pipelines.
- **Reference:** [`.github/workflows/`](.github/workflows/)

## Other Asset Bundles
Standalone Declarative Automation Bundles exploring the Bronze → Silver → Gold transformation lifecycle — `daily_capitals_weather` (weather ingestion) and `wc_bundle` (a Silver/Gold pipeline triggered when its upstream bronze updates).
- **Reference:** [`Databricks/bundles/`](Databricks/bundles/)

## Secrets & Privacy
A reusable `vault_secrets` Terraform module that pulls credentials from **HashiCorp Vault** (KV v2) at plan/apply time, keeping secrets out of code and `terraform.tfvars`. A separate exploration — not yet wired into the CDC pipeline, which currently authenticates via environment variables.
- **Reference:** [`Databricks/terraform/modules/vault_secrets/`](Databricks/terraform/modules/vault_secrets/)



## Notes

>  Some features are limited by the Databricks free tier. 

For detailed documentation on each area, see the referenced folders and files. Each relevant subfolder will contain its own README with further information.

The repository leverages:

* **Terraform installed on Ubuntu-based containers** for infrastructure provisioning and configuration
* **Databricks Terraform Provider** for workspace and platform configuration inside of the Terraform Scripts
* **AWS (RDS, DMS, S3, IAM)** for source databases, change data capture, storage, and cross-account access
* **Docker** for portable development environments
* **HashiCorp Vault** for centralized secret management
* **Databricks CLI** for deploying Declarative Automation Bundles and managing Databricks from your CLI

---

## Architecture

```text
┌─────────────────────────────────────────────┐
│            Developer Workstation            │
├─────────────────────────────────────────────┤
│  Code                                       │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│           Self-Hosted Docker Stack          │
├─────────────────────────────────────────────┤
│ Ubuntu Terraform Container                  │
│  • Terraform                                │
│                                             │
│ HashiCorp Vault Container                   │
│  • Local Secrets Management                 │
│  • Token Storage                            │
│  • Credential Management                    │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐ 
│                 Terraform                   │ 
├─────────────────────────────────────────────┤ 
│ Providers                                   │ 
│  • Databricks Provider                      │ 
│  • AWS Provider                             │ 
│  • Vault Provider                           │ 
└──────────┬──────────────────────────────────┘ 
           │                                    
           ▼                                    
┌─────────────────────────────────────────────┐
│               AWS (CDC Pipeline)            │
├─────────────────────────────────────────────┤
│ RDS MySQL (source w/ binlog)                │
│  └── DMS (full load + CDC replication)      │
│        └── S3 (Parquet landing zone)        │
│              └── IAM (cross-account roles)  │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐            ┌─────────────────────────────────────────────┐
│            Databricks Platform              │            │       Github Actions - CI/CD Pipeline       │
├─────────────────────────────────────────────┤            ├─────────────────────────────────────────────┤
│ Workspaces                                  │            │ Automated Deployments                       │
│ Jobs & Workflows                            │            │ Testing & Validation                        │
│ Unity Catalog (Auto Loader → Bronze Delta)  │ <--------  │ Infrastructure as Code (WIP)                │
│ Lakehouse Federation (live RDS queries)     │            │ Secrets Management                          │
│ Permissions & Access Controls               │            │ Monitoring & Observability (WIP)            │
│ Secret Scopes                               │            │                                             │
└─────────────────────────────────────────────┘            └─────────────────────────────────────────────┘
