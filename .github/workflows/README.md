# GitHub Actions

The repository's CI/CD: Terraform for platform resources, Databricks Asset
Bundles (DAB) for workloads, both flowing through PR checks into gated prod
deploys.

## Workflows

| Workflow | Triggers | What it does |
| --- | --- | --- |
| [`terraform.yml`](terraform.yml) | PR + push to `main` on `declarative_bronze/{ingestion,modules,provisioning}/**` | Terraform CI for declarative_bronze: fmt/validate on every PR (forks included); a `terraform plan` against the S3 state posted as a sticky PR comment; `declarative-bronze-prod`-gated `terraform apply` on merge. AWS auth via OIDC. |
| [`deploy_declarative_bronze.yml`](deploy_declarative_bronze.yml) | PR + push to `main` on `declarative_bronze/**` (minus `provisioning/`) | Bundle side of declarative_bronze: renders `pipeline.gen.yml`, `databricks bundle validate` + ruff on PR; `declarative-bronze-prod`-gated deploy of both bundles to prod on merge. |
| [`governance_access.yml`](governance_access.yml) | PR + push to `main` on `governance/**` | Access-as-code: lints `access_matrix.json` + member CSVs, posts a sticky access-diff comment on PR; `governance-prod`-gated `terraform apply` on merge. |
| [`deploy_dab_bundles.yml`](deploy_dab_bundles.yml) | push to `main` on `explorations/bundles/**` | Deploys the exploration bundles (`daily_capitals_weather`, `wc_bundle`) to prod via the Databricks CLI. |
| [`build_deply_module_wheels.yml`](build_deply_module_wheels.yml) | push to `main` on `explorations/notebooks/modules/**`, manual | Builds a wheel per module with a `pyproject.toml` and uploads it to `/Workspace/Shared/modules/<module>`. |
| [`pylint.yml`](pylint.yml) | every push | Repo-wide pylint gate (`--fail-under=8.0`). |

## Required secrets, variables, environments

| Kind | Name | Used by |
| --- | --- | --- |
| secret | `DATABRICKS_HOST` / `DATABRICKS_CLIENT_ID` / `DATABRICKS_CLIENT_SECRET` | bundle workflows, `governance_access.yml`, `terraform.yml` |
| secret | `DECLARATIVE_BRONZE_TFVARS` | `terraform.yml`, `deploy_declarative_bronze.yml` (prod tfvars, shape of `terraform.tfvars.example`) |
| secret | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | `governance_access.yml` only (legacy static keys) |
| variable | `TF_STATE_BUCKET` / `TF_STATE_REGION` | `governance_access.yml`, `terraform.yml` |
| environment | `governance-prod` | required-reviewer gate for governance applies |
| environment | `declarative-bronze-prod` | required-reviewer gate for declarative_bronze Terraform applies **and** bundle deploys |
