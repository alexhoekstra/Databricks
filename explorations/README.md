 # Explorations — Databricks & Terraform

This folder contains my exploratory Databricks and Terraform assets. These explorations have culminated in the
[`lakeflow_connect`](../lakeflow_connect/) CDC pipeline.

Everything here is a learning artifact built on the **Databricks Free Tier**, so
some experiments are shaped (or limited) by what the free tier allows. The three
areas below map to the tools each explores: Declarative Automation Bundles for
orchestration, notebooks/wheels for pipeline logic, and Terraform for
provisioning.

## Contents

### [`bundles/`](bundles/) — Declarative Automation Bundles (DABs)

Standalone DABs exploring the Bronze → Silver → Gold medallion lifecycle.

- [`daily_capitals_weather/`](bundles/daily_capitals_weather/) — daily ingestion and
  medallion processing of weather data from the [World Weather Repository](https://www.kaggle.com/datasets/nelgiriyewithana/global-weather-repository)
  Kaggle dataset. Generated from the `default-python` template, with a job, a
  pipeline, shared Python code, and unit tests.
- [`wc_bundle/`](bundles/wc_bundle/) — World Cup team statistics. Transforms the
  `main.wc.wc_teams_bronze` table (ingested by [`scalable_ingestion`](terraform/scalable_ingestion/))
  through Silver cleaning and Gold analytics layers, triggered when that bronze
  table updates. Auto-deployed by the [`deploy_dab_bundles.yml`](/.github/workflows/deploy_dab_bundles.yml)
  GitHub Action via a service principal.

### [`notebooks/`](notebooks/) — Notebooks, pipeline logic & reusable wheels

Jupyter notebooks and Python files, plus the packaged modules that back the
Terraform ingestion jobs.

- [`aq/`](notebooks/aq/) — an OpenAQ air-quality medallion pipeline: `aq_bronze_autoloader`
  (S3 → Delta via Auto Loader), `aq_silver_clean`, and `aq_gold_daily_summary`.
- [`world_cup/`](notebooks/world_cup/) — exploratory World Cup analysis notebook.
- [`modules/domain_batch_ingest/`](notebooks/modules/domain_batch_ingest/) — the
  reusable `domain_batch_ingest` wheel (`generic_extractor` + `generic_autoloader`)
  consumed by [`scalable_ingestion`](terraform/scalable_ingestion/). The
  [`build_deply_module_wheels.yml`](/.github/workflows/build_deply_module_wheels.yml)
  GitHub Action builds any module here and uploads it to `/Workspace/Shared/modules/`.
- [`tests/`](notebooks/tests/) — unit tests for the module's extractor and autoloader.

### [`terraform/`](terraform/) — Infrastructure & platform provisioning

Terraform scripts for provisioning Databricks workspace assets and running
ingestion.

- [`scalable_ingestion/`](terraform/scalable_ingestion/) — a configuration-driven
  ingestion framework: adding a new data domain is just a new `terraform.tfvars`
  entry (no new resources). Each domain gets a Unity Catalog schema, a managed
  landing volume, and a scheduled extract → autoload job built on the
  `domain_batch_ingest` wheel.
- [`modules/`](terraform/modules/) — reusable modules: `domain_batch_ingest` (the
  per-domain ingestion job), `unity_catalog_module` (UC schema/objects), and
  `vault_secrets` (pulls credentials from HashiCorp Vault at plan/apply time).
- [`dev/`](terraform/dev/) — Databricks provisioning experiments (UC creation,
  secrets, jobs, notebooks, schemas) and [`dev/provisioning/`](terraform/dev/provisioning/)
  covering account-level governance: users, groups, service principals, alerts,
  and OIDC federation.
