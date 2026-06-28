# domain_batch_ingest module

This module provisions a Databricks ingestion job for a domain-specific batch pipeline using a configurable source and target catalog.

## Variables

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| domain | string | null | The name of the domain |
| source_type | string | null | The name of the source (for example, kaggle, hugging_face, or url_zip) |
| source_config | object | null | Source-specific configuration values passed to the ingestion job |
| schedule | string | null | The Quartz cron expression for the job schedule |
| target_catalog | string | null | The name of the target catalog |
| sp | string | null | The display name of the service principal to use |
| wheel_version | string | 0.1.0 | The version of the wheel to deploy |
| mode | string | append | The write mode for the ingestion job |

## Source configuration examples

The module expects the source configuration to be provided as an object with at least a repository value and a list of filenames. The structure differs slightly by source type.

### Kaggle example

```hcl
source_config = {
  repo = "swaptr/fifa-wc-2026-teams"
  filenames = [
    {
      name  = "teams.csv"
      table = "wc_teams_bronze"
    }
  ]
}
```

### Hugging Face example

```hcl
source_config = {
  repo = "allenai/ai2_arc"
  filenames = [
    {
      name  = "ARC-Challenge/test-00000-of-00001.parquet"
      table = "arc_test_bronze"
    }
  ]
}
```

### URL ZIP example

```hcl
source_config = {
  repo = "https://example.com/archive.zip"
  filenames = [
    {
      name  = "*.csv"
      table = "summary_metrics_by_exchange_bronze"
    }
  ]
  headers = {
    "User-Agent" = "example-user"
  }
}
```

## Notes

- The module expects the source configuration to be supplied as an object in Terraform values.
- The target catalog and domain values are used to build the ingestion job metadata and table targets.
