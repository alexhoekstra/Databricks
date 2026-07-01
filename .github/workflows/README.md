# GitHub Actions

This folder contains the repository's GitHub Actions automation for continuous integration and deployment. The workflows help validate Python code, build distributable modules, and deploy Databricks resources.

## Contents

### `build_deply_module_wheels.yml`
This workflow runs when changes are pushed to the main branch under the explorations/notebooks/modules path. It:
- builds wheel files for each module that contains a pyproject.toml file
- uploads the generated wheels to the Databricks Workspace under /Workspace/Shared/modules/<module_name> using the Databricks CLI. Secrets for the authentication are stored in Github

This workflow is used to publish reusable Python modules for Databricks notebooks and jobs.

### `deploy_dcw_bundle.yml`
This workflow deploys the Databricks bundle located at `explorations/bundles/daily_capitals_weather` when changes are pushed to the main branch in that bundle's directory. It supports automated delivery of the daily_capitals_weather bundle.

### `pylint.yml`
This workflow runs on every push and validates Python code quality using pylint. It is intended to catch linting issues early in the development process.

## Required repository secrets
The deployment workflows rely on the following GitHub repository secrets:
- DATABRICKS_HOST
- DATABRICKS_CLIENT_ID
- DATABRICKS_CLIENT_SECRET

These values are used by the Databricks CLI during build and deployment steps.