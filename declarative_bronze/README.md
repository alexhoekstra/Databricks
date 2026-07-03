# declarative_bronze

Config-driven **raw→bronze** ingestion using **Lakeflow Declarative
Pipelines (DLT)** — a declarative alternative to the imperative Auto Loader wheel
job in [`lakeflow_connect`](../lakeflow_connect/). One generic pipeline ingests
every table in a domain from a shared `source_domain`,  and new tables are auto-discovered.

Bundle assumes the landing structure of (`s3://<bucket>/<DATE>/<table>.parquet`). The pipeline auto-discovers the tables in the bucket (each distinct file `<table>.parquet` becomes table`<table>_bronze`).

- **Bronze** — append-only copy + metadata columns:
  - `_ingest_ts` — processing time (when the pipeline ran).
  - `_source_file` — full landing path of the source file.
  - `_source_name` — logical table/source name.
  - `_batch_date` — **data recency**: the business date parsed from the dated
    landing folder `s3://<bucket>/<DATE>/<table>.parquet` (nullable when a file
    is not under a dated folder). Freshness monitoring in
    [`../data_quality`](../data_quality/) reads this — it is a published contract.
- **Toggle-able run mode** — pipeline-level `continuous` variable: `false` =
  triggered (auto-stops), `true` = always-on stream.
- **Incremental** — Auto Loader checkpoints processed files, so re-runs ingest
  only new files.

## Medallion architecture — two bundles, sequenced

Bronze ingestion and silver curation are **two separate DAB bundles with two DLT
pipelines**. Free Edition permits both pipelines to be *defined* but allows only
**one pipeline update active at a time**, so they must never run concurrently —
the `declarative_medallion` orchestration job sequences them.

```text
s3://<bucket>/<DATE>/<table>.parquet
        │
        ▼
  bundle/            declarative_bronze pipeline   (Terraform-generated resource)
   src/ingest_bronze.py  ──►  main.declarative_bronze.<table>_bronze   (append-only)
        │
        ▼   declarative_medallion job:  bronze_update ──► silver_update  (sequential)
        │
  bundle_curated/    declarative_curated pipeline  (hand-authored, committed)
   src/transform_silver.py  ──►  main.declarative_silver.<table>_silver       (SCD2)
        │                    └─►  main.declarative_silver.<table>_quarantine
        │
        ▼  (gold runs in the SAME pipeline, after silver — no third pipeline)
   src/transform_gold.py    ──►  main.declarative_gold.program_execution_gold
                            ├─►  main.declarative_gold.vendor_spend_gold
                            └─►  main.declarative_gold.fy_appropriation_gold
```

- **`bundle/`** — bronze ingestion. Its `resources/pipeline.gen.yml` is
  **Terraform-generated** (`../ingestion`); never hand-edit it.
- **`bundle_curated/`** — silver (+ future gold) curation. **Fully hand-authored
  and committed**; Terraform knows nothing about it. Users edit it directly and
  CI redeploys on merge.

### Silver contract (consumed by [`../data_quality`](../data_quality/))

- `<table>_silver` is an **SCD2** table (built with `apply_changes`), so it
  carries `__START_AT`/`__END_AT` and one current row per key
  (`__END_AT IS NULL`).
- `<table>_quarantine` holds rows that failed the table's expectations, tagged
  with `_quarantined_ts`.
- Both live in `main.declarative_silver` — a **naming-convention** contract; no
  config plumbing crosses between the projects.

### Gold contract (consumed by [`../data_quality`](../data_quality/))

Three **batch, materialized** aggregate tables in `main.declarative_gold`,
recomputed each update by [`bundle_curated/src/transform_gold.py`](bundle_curated/src/transform_gold.py)
inside the **same** `declarative_curated` pipeline — Free Edition forbids a third
pipeline, so gold joins silver's pipeline and runs after it. Each reads the
**SCD2-current** rows of silver only (`__END_AT IS NULL`) — never bronze, never
quarantine (so the quarantined rows, e.g. a negative obligation, are excluded from
the aggregates):

- `program_execution_gold` — grain `program_id`: contracts vs. obligations, with an
  `execution_rate_pct`.
- `vendor_spend_gold` — grain `vendor_id`: contract spend and concentration.
- `fy_appropriation_gold` — grain `fiscal_year × appropriation`: budget trend.

Conventions:

- **Naming** — each table carries a `_gold` suffix and publishes as
  `main.declarative_gold.<name>_gold`, a naming-convention contract like silver.
- **Grain** — one row per the grain listed above; the grain columns are unique in
  every gold table.
- **Freshness** — every gold table ends with `_computed_ts`
  (`current_timestamp()` at update time), the freshness signal `data_quality`
  monitors.
- **Cross-schema publish** — the pipeline's default schema is `declarative_silver`;
  gold tables target the separate `declarative_gold` schema via fully-qualified
  `@dlt.table` names (a direct-publishing-mode feature — the pipeline sets
  `catalog` + `schema`). The silver-read and gold-write locations are passed as
  pipeline `configuration` (`declarative_curated.silver_source` / `.gold_target`)
  resolved from the schema resources, so in the `dev` target they automatically
  carry the dev name prefix and gold stays dev-isolated.

### Adding a silver table

Edit **one JSON entry** under `declarative_curated.tables` in
[`bundle_curated/resources/pipeline.yml`](bundle_curated/resources/pipeline.yml)
(`primary_keys`, `sequence_by`, optional `expectations`), verify the column names
against the bronze data, and merge — CI redeploys the curated bundle. Tables
without a config entry are left untouched.

### Run-mode interaction

Setting bronze `continuous = true` holds the single account-wide active-update
slot and **starves the curated pipeline** — use it only for bounded demos while
`bundle_curated` is undeployed. Once curated is deployed, the
`declarative_medallion` job owns scheduling; bronze needs no schedule of its own.
