# Configuration Driven Scalable Ingestion — Terraform

Terraform configuration for a configuration-driven, scalable ingestion framework 
that extracts data from external sources and loads it into a Databricks Unity Catalog 
bronze table.

---

## How It Works

Completely configuration driven ingestion pipeline

Adding a new data domain requires only a new entry in `terraform.tfvars`<span style="font-size: 0.6em;">[link](terraform.tfvars.example)</span> 
— no additional Terraform resources needed. 


### Batch Ingestion:
Two generic notebooks are deployed to the Databricks shared workspace and invoked 
per domain via a scheduled job:

1. **`generic_extractor`** — Pulls data from the configured source and lands it in 
   a managed raw volume.
2. **`generic_autoloader`** — Picks up the landed files using Auto Loader and writes 
   them to the target bronze table(s) defined in the configuration file .



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
  arc_challenge = {
    source_type = "hugging_face"
    source_config = {
      repo = "allenai/ai2_arc"
      filenames = [
        {name = "ARC-Challenge/test-00000-of-00001.parquet", table = "arc_test_bronze"},
        {name = "ARC-Challenge/train-00000-of-00001.parquet",table = "arc_train_bronze"}, 
        {name = "ARC-Challenge/validation-00000-of-00001.parquet", table = "arc_validation_bronze"},
        {name = "ARC-Challenge/*.parquet", table = "arc_merged_bronze"}]
    }
    target_catalog = "main"
    schedule = "0 0 14 * * ?"
    sp = "sp-wc-pipeline" ##To implement
  },
}
```

Terraform will provision the schema, volume, and job automatically. All data will be ingested into your defined table(s)