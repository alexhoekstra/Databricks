# Scalable Ingestion — Terraform

Terraform configuration for a configuration-driven, scalable ingestion framework 
that extracts data from external sources and loads it into a Databricks Unity Catalog 
bronze table.

---

## How It Works
Adding a new data domain requires only a new entry in `terraform.tfvars` 
— no additional Terraform resources needed.

### Batch Ingestion:
Two generic notebooks are deployed to the Databricks shared workspace and invoked 
per domain via a scheduled job:

1. **`generic_extractor`** — Pulls data from the configured source and lands it in 
   a managed raw volume.
2. **`generic_autoloader`** — Picks up the landed files using Auto Loader and writes 
   them to the target bronze table.



---

## Module: `domain_batch_ingest` <span style="font-size: 0.6em;">[link](../modules/domain_batch_ingest/)</span>

Each domain is provisioned through the `domain_batch_ingest` module, which creates:

| Resource | Description |
|---|---|
| `databricks_schema` | Unity Catalog schema scoped to the domain |
| `databricks_volume` | Managed volume used as the raw landing zone |
| `databricks_job` | Two-task scheduled job (extract → autoload) |

The job runs on a configurable cron schedule (paused by default) and passes 
`source_config` and `source_type` as parameters to each notebook task.

---

## Adding a Domain

Add an entry to `domains` in your `terraform.tfvars`:

```hcl
domains = {
  fifa = {
    source_type   = "kaggle"
    source_config = {
      dataset = "swaptr/fifa-wc-2026-teams"
      filename = "teams.csv"
    }
    target_table = "wc_teams_bronze"
    target_catalog = "main"
    schedule      = "0 0 * * * ?"
  }
}
```

Terraform will provision the schema, volume, and job automatically.