# Databricks Platform Engineering Exploration

 

This repository contains elements and experiments from my journey as I learn about Databricks Platform Engineering. Below are the main areas of focus, each referencing a section of the codebase where more detailed documentation can be found.
This was all done on Databricks Free Tier, so there are some limitations to what could be experimented on.

## Musings

While Terraform provides the ability to do many things, its core strength is in the managing of the workspace and infrastructure. Databricks Declarative Automation Bundles provide a seemingly better way in Databricks to orchestrate jobs/pipelines/notebooks. Using these together provides the best benefit.

The boundry from ingestion -> raw data -> bronze seems to be a bit murky sometimes and it seems to depend on the use case. Do you want/need to maintain a copy of the raw data in Databricks, or do you want to just ingest it directly into a bronze table?

 To add to that complexity, do you need to keep it in a temporary drop point so once its processed its deleted? Or do you need to keep it as a raw archive for lineage/auditability?

I experimented with a few options:
- Open Air Quality
  - Completely terraform managed job (mislabed as a pipeline) that creates a job with tasks that pull the data and creates bronze/silver/gold 
- Daily Capitals Weather
  - Completly Declarable Asset Bundle managed ingestion and transformations
- Fifa World Cup 2026 teams data
  - Initially started as pulling the data into a volume and then creating a bronze table, but converted to using kagglehub to directly pull the data and transform into a bronze table.  
  - I plan to revisit and create a second bronze table with the volume method.

 
## Overview

## 1. CI/CD with GitHub Actions

Automated deployment and testing pipelines are managed with GitHub Actions.

- **Reference:** [.github/workflows/](.github/workflows/) (workflow YAMLs)

 

## 2. Infrastructure as Code

Infrastructure is provisioned(as available by free tier) and managed using Terraform scripts.

- **Reference:** [Databricks/terraform/provisioning/](Databricks/terraform/provisioning/)

 

## 3. Automation of Raw to Bronze Layer

Raw data is ingested to the bronze layer (fifa_world_cup)

- **Reference:** [Databricks/terraform/dev/jobs.tf](Databricks/terraform/dev/jobs.tf)
- **Reference:** [Databricks/terraform/dev/notebooks.tf](Databricks/terraform/dev/notebooks.tf)

DAB performing ingestion using the python wheel file, and a daily job refreshing the pipeline, performing transformations to Bronze/Silver/Gold
- **Reference:** [Databricks/bundles/daily_capitals_weather/](Databricks/bundles/daily_capitals_weather/)
 

## 4. Scalable Ingestion Framework

Sample Databricks Asset Bundle performing data ingestion.  (Provisioning limited by Free Tier)

- **Reference:** [Databricks/bundles/daily_capitals_weather/src/daily_capitals_weather_etl/](Databricks/bundles/daily_capitals_weather/src/daily_capitals_weather_etl/)



## 5. Implementing Privacy in Scripts

Privacy and data protection best practices are implemented in scripts. Vault is used as a local secrets manager along with Databricks and Github Secrets

- **Reference:** [Databricks/terraform/](Databricks/terraform/)

 

## 6. Platform Monitoring & Observability

Monitoring, alerting, and observability infrastructure for the platform.

- **Reference:** [Databricks/terraform/provisioning/](Databricks/terraform/provisioning/)
- **Reference:** [Databricks/terraform/dev/jobs.tf](Databricks/terraform/dev/jobs.tf) (resource "databricks_alert_v2" "max_players_exceeded_alert")

 

---

 

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

### Deployment Flow

```text
Developer
    │
    ▼
Terraform Container
    │
    ├── Retrieves credentials from Vault
    │
    ▼
Terraform Providers
    │
    ├── Vault Provider
    ├── Databricks Provider
    │
    ▼
Databricks Platform
```
