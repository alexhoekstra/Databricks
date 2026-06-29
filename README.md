# Databricks Platform Engineering Exploration

This repository contains elements and experiments from my journey as I learn about 
Databricks Platform Engineering. Below are the main areas of focus, each referencing a section of the codebase where more detailed
documentation can be found.

### Musings

While Terraform can do many things, its core strength is managing workspace infrastructure. Databricks Asset Bundles (DABs) offer a more natural fit for orchestrating jobs, pipelines, and notebooks within Databricks. Used together, 
each handles what it does best.

One area that took some exploration was the boundary between ingestion, raw data, and bronze. The right approach seems to depend on the
use case. Do you need to preserve a copy of the raw data, or ingest directly into bronze? Should files be staged temporarily and deleted
after processing, or retained as a raw archive for lineage and auditability? 

>:heart: ***The [`terraform/aws`](Databricks/terraform/aws/) project is where that exploration comes together — a full-stack CDC pipeline from AWS RDS MySQL through DMS and S3 into Databricks Unity Catalog, with Lakehouse Federation for live querying, all provisioned end-to-end with Terraform.***
 
# Overview

## CI/CD — GitHub Actions
Automated deployment, dependency building, and testing pipelines.
- **Reference:** [`.github/workflows/`](.github/workflows/)

## AWS CDC Pipeline (RDS → Databricks) - Terraform
Full-stack change data capture pipeline provisioned entirely with Terraform. Streams row-level changes from an AWS RDS MySQL database through DMS and S3 into Databricks Unity Catalog bronze Delta tables via Auto Loader, with a Lakehouse Federation foreign catalog for live querying without ETL.
- **Reference:** [`Databricks/terraform/aws/`](Databricks/terraform/aws/)

## Declarative Automation Bundles (DABs)
DAB-based pipelines covering the full Bronze → Silver → Gold transformation lifecycle, including a bundle that triggers downstream processing when the AWS CDC pipeline lands new data in bronze
- **Reference:** [`Databricks/bundles/`](Databricks/bundles/)

## Secrets & Privacy
Secrets managed across three layers: HashiCorp Vault (local), Databricks Secrets, 
and GitHub Secrets.
- **Reference:** [`Databricks/terraform/`](Databricks/terraform/)



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

Terraform is used as the primary automation framework for deploying and managing Databricks resources. The Databricks Terraform Provider enables management of workspace objects, jobs, clusters, permissions, secret scopes, Unity Catalog components, and other platform resources inside Terraform.

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
