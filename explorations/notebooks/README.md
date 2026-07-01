# Notebooks — Pipeline logic & reusable wheels

Databricks notebooks, Python source, and the packaged modules that back the
Terraform ingestion jobs. This is where the pipeline logic is explored before
being promoted into bundles or Terraform-driven jobs.

## Contents

### [`aq/`](aq/)

An OpenAQ air-quality medallion pipeline, built as three parameterized notebooks:

- `aq_bronze_autoloader.py` — ingests OpenAQ data from S3 with Auto Loader and
  writes it to a Delta table in append mode (source partitioned by location ID and
  year; parameterized via widgets).
- `aq_silver_clean.py` — cleans and conforms the bronze data.
- `aq_gold_daily_summary.py` — aggregates the silver data into a daily summary
  gold table.

### [`world_cup/`](world_cup/)

`world_cup.ipynb` — an exploratory World Cup analysis notebook.

### [`modules/`](modules/)

Reusable Python packages built into wheels and deployed to Databricks. The
[`build_deply_module_wheels.yml`](/.github/workflows/build_deply_module_wheels.yml)
GitHub Action builds any module here and uploads it to `/Workspace/Shared/modules/`.

- [`domain_batch_ingest/`](modules/domain_batch_ingest/) — the configuration-driven
  ingestion wheel consumed by [`scalable_ingestion`](../terraform/scalable_ingestion/).
  It pairs a `generic_extractor` (pulls data from Kaggle, Hugging Face, or a URL
  zip into a landing volume) with a `generic_autoloader` (auto-detects file format
  and loads it into bronze tables).

### [`tests/`](tests/)

Unit tests for the `domain_batch_ingest` module (`test_generic_extractor.py`,
`test_generic_autoloader.py`). Run with `pytest` from this folder — see
[`pytest.ini`](pytest.ini) for configuration.
