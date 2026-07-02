# declarative_bronze

Config-driven **raw→bronze** ingestion using **Lakeflow Declarative
Pipelines (DLT)** — a declarative alternative to the imperative Auto Loader wheel
job in [`lakeflow_connect`](../lakeflow_connect/). One generic pipeline ingests
every table in a domain from a shared `source_domain`,  and new tables are auto-discovered.

Bundle assumes the landing structure of (`s3://<bucket>/<DATE>/<table>.parquet`). The pipeline auto-discovers the tables in the bucket (each distinct file `<table>.parquet` becomes table`<table>_bronze`).

- **Bronze** — append-only copy + metadata columns (`_ingest_ts`,
  `_source_file`, `_source_name`)
- **Toggle-able run mode** — pipeline-level `continuous` variable: `false` =
  triggered (auto-stops), `true` = always-on stream.
- **Incremental** — Auto Loader checkpoints processed files, so re-runs ingest
  only new files.

