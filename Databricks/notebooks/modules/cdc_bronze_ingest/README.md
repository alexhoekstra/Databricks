# cdc_bronze_ingest

Configuration-driven Auto Loader ingestion of **DMS CDC Parquet files** into
**Unity Catalog bronze Delta tables**. Packaged as a Python wheel so it can be
deployed and run as a module by a Databricks Asset Bundle (`python_wheel_task`).

This is the wheel form of the former `autoloader_cdc_bronze.py` notebook from the
`lakeflow_connect` pipeline.

## What it does

DMS writes CDC events to S3 as Parquet under
`s3://<bucket>/dms-cdc/<schema>/<table>/YYYY/MM/DD/*.parquet`, each row carrying
an `Op` column (`I`/`U`/`D`). For every table prefix it discovers, the job:

1. Discovers all table prefixes under the CDC root (no hardcoded table list).
2. Starts one Auto Loader stream per table (schema inferred + evolved).
3. Appends to an append-only bronze Delta table, preserving the CDC `Op` as
   `_op` plus ingestion lineage columns (`_ingested_at`, `_source_file`,
   `_source_table`).
4. Runs in `availableNow` trigger mode — processes everything landed since the
   last checkpoint, then stops (correct for a scheduled batch job).

## Layout

```
cdc_bronze_ingest/
├── pyproject.toml
├── README.md
├── src/cdc_bronze_ingest/
│   ├── __init__.py     — public API
│   ├── config.py       — IngestionConfig: arg parsing + path conventions (pure)
│   ├── discovery.py    — discover_tables(): list DMS table prefixes in S3
│   ├── streaming.py    — stream_table_to_bronze(): one Auto Loader stream
│   └── ingest.py       — run() orchestration + main() console entry point
└── tests/              — unit tests for the pure logic (no Spark required)
```

The Spark/`dbutils` boundary is isolated in `streaming.py`, `discovery.py`, and
`ingest.main()`; `config.py` is pure and fully unit-tested.

## Parameters

Passed as `named_parameters` (`--key value`) by the wheel task or CLI:

| Parameter | Required | Description |
|-----------|----------|-------------|
| `--s3_cdc_prefix` | yes | S3 prefix DMS writes to, e.g. `s3://bucket/dms-cdc` |
| `--source_schema` | yes | Source MySQL database name, e.g. `mydb` |
| `--target_catalog` | yes | UC catalog for bronze tables, e.g. `main` |
| `--target_schema` | yes | UC schema for bronze tables, e.g. `lakeflow_staging` |
| `--checkpoint_base` | yes | S3 path for Auto Loader checkpoints |
| `--bronze_suffix` | no | Suffix for bronze table names (default `_raw`) |

## Build

```bash
cd Databricks/notebooks/modules/cdc_bronze_ingest
pip install build
python -m build --wheel        # -> dist/cdc_bronze_ingest-0.1.0-py3-none-any.whl
```

## Test

```bash
pip install -e ".[dev]"
pytest
```

## Run as a Databricks Asset Bundle task

```yaml
resources:
  jobs:
    cdc_bronze_ingestion:
      tasks:
        - task_key: autoloader_bronze
          python_wheel_task:
            package_name: cdc_bronze_ingest
            entry_point: cdc_bronze_ingest          # from [project.scripts]
            named_parameters:
              s3_cdc_prefix: "s3://${var.bucket}/dms-cdc"
              source_schema: "mydb"
              target_catalog: "main"
              target_schema: "lakeflow_staging"
              checkpoint_base: "s3://${var.bucket}/checkpoints/cdc-bronze"
          libraries:
            - whl: ./dist/cdc_bronze_ingest-0.1.0-py3-none-any.whl
```

`pyspark` and `databricks-sdk` are provided by the Databricks Runtime and are
deliberately not declared as install requirements; they are available under the
`dev` extra for local development only.
