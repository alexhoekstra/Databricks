# declarative_bronze — auto-discovering raw→bronze→silver→gold (Terraform + DAB)

Config-driven raw→bronze ingestion with Declarable Automation Bundles,
plus a curated silver/gold layer on top. One generic pipeline ingests every
table in a domain from a shared `source_domain`; new tables are
auto-discovered from the landing bucket. The work is split across two tools
by what each does best:

- **Terraform (`ingestion/`)** — domain-level Unity Catalog governance (storage
  credential, external location, grants) and generation of the bronze
  bundle's `pipeline.gen.yml` from `terraform.tfvars`.
- **Databricks Asset Bundles** — two of them:
  - [`bundle/`](bundle/) — deploys the bronze schema + the generated
    `declarative_bronze` pipeline.
  - [`bundle_curated/`](bundle_curated/) — hand-authored `declarative_curated`
    pipeline (SCD2 silver + gold aggregates) and the `declarative_medallion`
    job that sequences bronze → silver.

> This is the Declarative Automation Bundle alternative to the Auto Loader wheel
> job in [`lakeflow_connect`](../lakeflow_connect/): instead of one job per
> domain running wheel code, one declarative pipeline discovers and ingests
> every table under the domain's landing path.

## Architecture

```text
domain lands files in object storage
    s3://<bucket>/
    └── declarative_bronze pipeline (auto-discovers each <table>.parquet stem)
          └── <table>_bronze Delta tables (main.declarative_bronze)
                └── declarative_curated pipeline (SCD2 silver + quarantine,
                    then gold aggregates in the same update)
                      └── main.declarative_silver / main.declarative_gold

The declarative_medallion job sequences bronze → silver on a daily schedule
(max one concurrent run due to Free Edition allowing one active update at a time).
Auto Loader checkpoints processed files, so re-runs ingest only new files.
```

Each bronze table is an append-only copy of the source plus metadata columns:
`_ingest_ts` (processing time), `_source_file` (landing path), `_source_name`
(logical table name), and `_batch_date` (parsed from the dated landing folder).

## Layout

```text
declarative_bronze/
├── provisioning/     — S3 landing bucket + UC cross-account
│                       IAM role + seed data.
├── ingestion/        — UC governance + pipeline generation
│   └── terraform.tfvars   — the source_domain + pipeline config
├── modules/
│   └── source_ingest/ — storage credential + external location + optional grants
├── bundle/            — the bronze DAB
└── bundle_curated/    — the curated DAB (hand-authored, committed)
```

Each sub-tree has its own README: [`ingestion/`](ingestion/README.md),
[`modules/source_ingest/`](modules/source_ingest/README.md),
[`provisioning/`](provisioning/README.md).

## Run modes & guardrails

All set in `ingestion/terraform.tfvars` (see the
[ingestion README](ingestion/README.md) for the full variable table):

- **`continuous`** — `false` = triggered (Free Tier safe), `true` = continuous stream (Not Free Tier Safe).
- **`fail_on_empty`** — raise (vs. warn) when discovery finds no files, guarding
  against silent data loss.
- **`include_tables` / `exclude_tables`** — allow/deny lists of files at the root.

## Deploy

```bash
# 0. (once) stand up the landing bucket + UC IAM role — see provisioning/ for the example

# 1. Terraform: UC governance + generate the bundle's pipeline file
cd ingestion
cp terraform.tfvars.example terraform.tfvars   # edit source_domain etc.
terraform init
terraform apply

# 2. Bronze bundle: deploy the schema + generated pipeline
cd ../bundle
databricks bundle validate
databricks bundle deploy -t dev

# 3. Curated bundle: silver/gold pipeline + medallion job
#    (dev needs an explicit bronze pipeline id — see bundle_curated/databricks.yml)
cd ../bundle_curated
databricks bundle deploy -t dev --var="bronze_pipeline_id=<id>"

# 4. Run the full medallion job (bronze → silver/gold)
databricks bundle run declarative_medallion -t dev
```

Apply order matters: Terraform generates `bundle/resources/pipeline.gen.yml`
that the bronze bundle deploys, so Terraform first, then the bundles.

## Adding a table

- **Bronze** — drop `<table>.parquet` into the landing folder and re-run the
  pipeline; discovery picks it up. No config or code changes.
- **Silver** — add one JSON entry (`primary_keys`, `sequence_by`, optional
  `expectations`) under `declarative_curated.tables` in
  `bundle_curated/resources/pipeline.yml` and merge; CI redeploys the bundle.

## CI/CD

Two GitHub workflows cover this directory (see
[`.github/workflows/README.md`](../.github/workflows/README.md)):

- **`terraform.yml`** — fmt/validate on every PR, plan as a sticky PR comment,
  gated `terraform apply` on merge.
- **`deploy_declarative_bronze.yml`** — renders `pipeline.gen.yml` + bundle
  validate on PR; gated deploy of both bundles to prod on merge.
