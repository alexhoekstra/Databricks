# Databricks Platform Engineering Exploration - Terraform

This portion of the repository contains my exploration and building depth of knowledge about Databricks with Terraform. 

This was all done on Databricks Free Tier, so there are some limitations to what could be experimented on.

## Areas of Focus

## 1. Infrastructure as Code

Infrastructure is provisioned(as available by free tier) and managed using Terraform scripts.

- **Reference:** [provisioning/](provisioning/)

## 2. Automation of Raw to Bronze Layer

Raw data is ingested to the bronze layer and transformed in Silver/Gold through automated ETL pipelines and jobs.

- **Reference:** [jobs.tf](jobs.tf)
- **Reference:** [notebooks.tf](notebooks.tf)

## 3. Implementing Privacy in Scripts

Privacy and data protection best practices are implemented in scripts. Vault is used as a local secrets manager along with Databricks and Github Secrets


## 4. Platform Monitoring & Observability

Monitoring, alerting, and observability infrastructure for the platform.

- **Reference:** [provisioning/](provisioning/)
- **Reference:** [jobs.tf](jobs.tf) (resource "databricks_alert_v2" "max_players_exceeded_alert")

## 5. Terraform Reuse (Modules

Self-contained, reusable packages of Terraform configurations

- **Reference:** [modules/](modules/)

Usage examples:
- **Reference:** [databricks_secrets.tf](databricks_secrets.tf)
- **Reference:** [jobs.tf](jobs.tf)

## Key Databricks functions

- `automated_UC_creation.tf`: Demonstrates automated Unity Catalog schema/table creation using the `unity_catalog_module`.
- `databricks_secrets.tf`: Creates a Databricks secret scope and writes Vault-derived application secrets into Databricks.
- `jobs.tf`: Defines scheduled Databricks jobs for OpenAQ and FIFA data pipelines, including notebook task orchestration and alerting.
- `notebooks.tf`: Pushes local notebook source files into Databricks workspace paths so jobs can execute them.
- `schema.tf`: Creates Unity Catalog schemas and managed volumes for OpenAQ and World Cup workloads, with free-tier workarounds documented.
##
