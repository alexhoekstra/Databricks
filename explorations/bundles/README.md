# Declarative Automation Bundles — Databricks

This folder contains the repository's Declarative Automation Bundles (DABs) —
standalone bundles exploring the Bronze → Silver → Gold medallion lifecycle. Each
bundle bundles its own job/pipeline definitions, shared Python source, and tests,
and is deployed with the Databricks CLI.

## Contents

### [`daily_capitals_weather/`](daily_capitals_weather/)

Handles daily ingestion and medallion processing of weather data pulled from the
[World Weather Repository (Daily Updating)](https://www.kaggle.com/datasets/nelgiriyewithana/global-weather-repository)
Kaggle dataset. Generated from the `default-python` template and extended with a
job, an ETL pipeline, Bronze/Silver/Gold transformations, shared Python code, and
unit tests.

### [`wc_bundle/`](wc_bundle/)

A World Cup team-statistics pipeline holding Silver and Gold tables. It transforms
the `main.wc.wc_teams_bronze` table — created by
[`scalable_ingestion`](../terraform/scalable_ingestion/) — through Silver cleaning
and Gold analytics (rankings and country-level rollups). The pipeline runs on a
trigger that fires when that bronze table updates, and the bundle is auto-deployed
by the [`deploy_dab_bundles.yml`](/.github/workflows/deploy_dab_bundles.yml) GitHub
Action using a service principal.
