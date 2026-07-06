# Databricks Platform Engineering Exploration

This repository contains elements and experiments from my journey as I learn about 
Databricks Platform Engineering. Below are the main areas of focus, each referencing a section of the codebase where more detailed
documentation can be found.

### Musings

While Terraform can do many things, its core strength is managing workspace infrastructure. Declarative Automation Bundles (DABs) offer a more natural fit for orchestrating jobs, pipelines, and notebooks within Databricks. Used together, 
each handles what it does best.

# Overview

## lakeflow_connect — AWS CDC Pipeline (Terraform + DAB)
A full-stack change data capture pipeline capturing row-level changes from an AWS RDS MySQL database through DMS and S3 into Databricks Unity Catalog bronze Delta tables via Auto Loader, with an optional Lakehouse Federation foreign catalog for live querying without ETL. It splits the work by what each tool does best — **Terraform** owns per-domain Unity Catalog governance (storage credential, external location, optional federation) while a **Declarative Automation Bundle** builds the `cdc_bronze_ingest` wheel and deploys each domain's bronze schema, checkpoint volume, and Auto Loader job. The whole pipeline is declared in one `terraform.tfvars` `domains` map, so adding a source system needs no new code.
- **Reference:** [`lakeflow_connect/`](lakeflow_connect/)

## declarative_bronze — Lakeflow Declarative Pipelines Ingestion
Config-driven raw → bronze ingestion using **Lakeflow Declarative Pipelines (DLT)** — a declarative alternative to the Auto Loader wheel job in `lakeflow_connect`. One generic pipeline auto-discovers and ingests every table in a domain's landing bucket, and a second bundle adds a silver (SCD2) layer, sequenced by an orchestration job into a bronze → silver medallion flow.
- **Reference:** [`declarative_bronze/`](declarative_bronze/)

## governance — Config-Driven Unity Catalog Permissions
Unity Catalog security automation where config maps drive everything via `for_each` — adding a team, a catalog, or a member is a config edit, not a new Terraform script. Teams, memberships, and schema grants are declared in an access matrix and per-team CSVs, projected down to per-user grants to work around Free Edition's workspace-local groups.
- **Reference:** [`governance/`](governance/)

## network — Customer-Managed Databricks VPCs
Multi-VPC AWS networking for Databricks: a `vpcs` map creates one VPC module instance per entry (a `workspace` VPC with the documented Databricks subnets, security-group rules, and endpoints, plus an `ingest` VPC for DMS-style landing infrastructure), peered together at the root. Its outputs drop straight into `workspace_vending`.
- **Reference:** [`network/`](network/)

## workspace_vending — Databricks Workspace Creation on AWS
Config-driven workspace vending at the account level: each entry in a `workspaces` map creates the AWS prerequisites (cross-account IAM role, root bucket) and the `databricks_mws_*` registrations that make a workspace. Written and `terraform validate`d, but not applied — Free Edition cannot authenticate to the account API.
- **Reference:** [`workspace_vending/`](workspace_vending/)

## CI/CD — GitHub Actions
Automated deployment, dependency building, and testing pipelines.
- **Reference:** [`.github/workflows/`](.github/workflows/)

Smaller experiments — standalone asset bundles and a reusable Vault secrets module live in [`explorations/`](explorations/).



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
│ HashiCorp Vault Container (exploration)     │
│  • Local Secrets Management                 │
│  • Token Storage                            │
│  • Credential Management                    │
└─────────────────────┬───────────────────────┘
                      │
                      ├──────────────────────────────────────────────────────────┐
                      ▼                                                          ▼
┌─────────────────────────────────────────────┐            ┌─────────────────────────────────────────────┐
│                 Terraform                   │            │       Databricks CLI (Asset Bundles)        │
├─────────────────────────────────────────────┤            ├─────────────────────────────────────────────┤
│ Providers                                   │            │ Builds pipeline wheels                      │
│  • Databricks Provider (workspace+account)  │            │ Deploys jobs & DLT pipelines                │
│  • AWS Provider                             │            │ (lakeflow_connect · declarative_bronze)     │
│  • Vault Provider                           │            └─────────────────────┬───────────────────────┘
└──────────┬──────────────────────────────────┘                                  │
           │                                                                     │
           ▼                                                                     │
┌─────────────────────────────────────────────┐                                  │
│                     AWS                     │                                  │
├─────────────────────────────────────────────┤                                  │
│ CDC pipeline (lakeflow_connect)             │                                  │
│  RDS MySQL → DMS → S3 landing → IAM         │                                  │
│ Networking (network)                        │                                  │
│  workspace + ingest VPCs, peering, endpoints│                                  │
│ Workspace prereqs (workspace_vending) *     │                                  │
│  cross-account IAM role + root bucket       │                                  │
└─────────────────────┬───────────────────────┘                                  │
                      │              ┌───────────────────────────────────────────┘
                      ▼              ▼
┌─────────────────────────────────────────────┐            ┌─────────────────────────────────────────────┐
│            Databricks Platform              │            │       Github Actions - CI/CD Pipeline       │
├─────────────────────────────────────────────┤            ├─────────────────────────────────────────────┤
│ Workspaces                                  │            │ Automated Deployments (Terraform + DABs)    │
│ Jobs & DLT Pipelines (bronze → silver)      │            │ Testing & Validation                        │
│ Unity Catalog (Auto Loader → Bronze Delta)  │ <--------  │ Infrastructure as Code (WIP)                │
│ UC Governance (schemas · groups · grants)   │            │ Secrets Management                          │
│ Lakehouse Federation (live RDS queries)     │            │ Monitoring & Observability (WIP)            │
│ Workspace vending via account API *         │            │                                             │
└─────────────────────────────────────────────┘            └─────────────────────────────────────────────┘

* written and validated; not applied on Free Edition
