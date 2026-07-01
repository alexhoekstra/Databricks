# Configuration Driven Scalable Ingestion — Terraform

Terraform configuration for a configuration-driven, scalable ingestion framework that extracts data from external
sources and loads it into a bronze table. See [`wc_bundle`](/explorations/bundles/wc_bundle/) for an example 
Declarative Automation Bundle that is triggered off a bronze table update from a domain.

---

## How It Works

Completely configuration driven ingestion pipeline. Minimal configuration needed. Core functionality is implemented in the `domain_batch_ingest` module.

Adding a new data domain requires only a new entry in [`terraform.tfvars`](terraform.tfvars)
— no additional Terraform resources needed.



---

## Module: `domain_batch_ingest` <span style="font-size: 0.6em;">[link](../modules/domain_batch_ingest/)</span>

Each domain is provisioned through the `domain_batch_ingest` module, which creates:

| Resource | Description |
|---|---|
| `databricks_schema` | Unity Catalog schema scoped to the domain |
| `databricks_volume` | Managed volume in the schema used as the raw landing zone |
| `databricks_job` | Scheduled job with two tasks  (extract → autoload) |

The job runs on a configurable cron schedule (paused by default) and can optionally be configured to run as a existing service principal. 

### Dependencies :
Both tasks are configured to run a python_wheel_task. This github repo is configured with a [github action](/.github/workflows/build_deply_module_wheels.yml) that will build wheels for any modules listed in [`/explorations/notebooks/modules`](/explorations/notebooks/modules) and upload them to Databricks at `/Workspace/Shared/modules/{module_name}`.

---

## Configuration

> The python files are named `{domain}-{version}--py3-none-any.whl`. You can specify a `wheel_version` in your `.tfvars` domain entries to lock it to a specific version in case of breaking updates.

### Adding a domain
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
    sp = "auto_ingest_sp"
    mode = "overwrite"
    wheel_version = "0.1.1"
  },
}
```

Terraform will provision the schema, volume, and job automatically. All data will be ingested into your defined table(s).

### Bronze Table Behavior
    mode = "overwrite"
Configuration of table behavior (overwrite, append, etc.) can be done per domain.