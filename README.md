# Databricks Platform Engineering Exploration

This repository contains elements and experiments from my journey as I learn about 
Databricks Platform Engineering. Below are the main areas of focus, each referencing a section of the codebase where more detailed
documentation can be found.

## Musings

While Terraform can do many things, its core strength is managing workspace infrastructure. Databricks Asset Bundles (DABs) offer a more natural fit for orchestrating jobs, pipelines, and notebooks within Databricks. Used together, 
each handles what it does best.

One area that took some exploration was the boundary between ingestion, raw data, and bronze. The right approach seems to depend on the
use case. Do you need to preserve a copy of the raw data, or ingest directly into bronze? Should files be staged temporarily and deleted
after processing, or retained as a raw archive for lineage and auditability? 

The [`scalable_ingestion`](Databricks/terraform/scalable_ingestion/) folder is where I'm putting that exploration into practice.
 
## Overview

> **Note:** Some features are limited by the Databricks free tier.

---

## 1. CI/CD — GitHub Actions
Automated deployment and testing pipelines.
- **Reference:** [.github/workflows/](.github/workflows/)

---

## 2. Infrastructure as Code — Terraform
Workspace infrastructure provisioned and managed via Terraform.
- **Reference:** [Databricks/terraform/](Databricks/terraform/)

---

## 3. Scalable Ingestion Framework (Raw → Bronze)
A configuration-driven ingestion framework providing consistent, scalable raw-to-bronze 
layer processing.
- **Reference:** [Databricks/terraform/scalable_ingestion/](Databricks/terraform/scalable_ingestion/)

---

## 4. Databricks Asset Bundles (DABs)
DAB-based pipelines covering the full Bronze → Silver → Gold transformation lifecycle, 
including a daily refresh job and a packaged Python wheel.
- **Reference:** [Databricks/bundles/daily_capitals_weather/](Databricks/bundles/daily_capitals_weather/)

---

## 5. Secrets & Privacy
Secrets managed across three layers: HashiCorp Vault (local), Databricks Secrets, 
and GitHub Secrets.
- **Reference:** [Databricks/terraform/](Databricks/terraform/)

---

## 6. Monitoring & Observability
Platform alerting and observability, including Delta Live Table alerts.
- **Reference:** [Databricks/terraform/provisioning/](Databricks/terraform/provisioning/)
- **Reference:** [jobs.tf](Databricks/terraform/dev/jobs.tf) — `databricks_alert_v2`
 

---
---
## Notes
 

For detailed documentation on each area, see the referenced folders and files. Each relevant subfolder will contain its own README with further information.

The repository leverages:

* **Terraform installed on Ubuntu-based containers** for infrastructure provisioning and configuration
* **Databricks Terraform Provider** for workspace and platform configuration inside of the Terraform Scripts
* **Docker** for portable development environments
* **HashiCorp Vault** for centralized secret management
* **Databricks CLI** for deploying Declarative Automation Bundles and managing Databricks from your CLI

Terraform is used as the primary automation framework for deploying and managing Databricks resources. The Databricks Terraform Provider enables management of workspace objects, jobs, clusters, permissions, secret scopes, Unity Catalog components, and other platform resources inside Terraform.

---

## Architecture

```text
┌─────────────────────────────────────────────┐
│            Developer Workstation            │
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
│  • Secrets Management                       │
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
│  • Vault Provider                           │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│            Databricks Platform              │
├─────────────────────────────────────────────┤
│ Workspaces                                  │
│ Jobs & Workflows                            │
│ Unity Catalog                               │
│ Permissions & Access Controls               │
│ Secret Scopes                               │
└─────────────────────────────────────────────┘
```
