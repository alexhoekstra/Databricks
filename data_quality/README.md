# data_quality

Scaffold for a data quality & observability layer. - Not yet implemented

Config-driven **data quality & observability** layer over Unity Catalog tables.
This project is meant to explore "governing & observeing" the ingestion projects in this repo. Plan to layer on top of [`declarative_bronze`](../declarative_bronze/) (or any UC table).

**Layer-aware metrics** (a `layer` discriminator in config selects the set):

- **Bronze** — operational/observability: freshness, volume/throughput,
  ingestion completeness, `_rescued_data` schema-drift, duplicate-arrival rate.
- **Silver** — content-quality/conformance: expectation/quarantine rate, PK
  uniqueness, SCD correctness, bronze→silver reconciliation, distribution drift.

Results land in a history table → SQL alerts on breaches → AI/BI dashboard with
separate bronze (ingestion health) and silver (data quality) tabs.

> **Status: scaffold.** Files under `checks/`, `bundle/`, `ci/` are stubs with
> TODOs. See [PLAN.md](PLAN.md) for the full design.
>
> **Verify first:** whether `databricks_quality_monitor` (Lakehouse Monitoring)
> is available on Free Edition — the default is a portable check-job + system
> tables fallback.

## Free-Edition limitations to remember

- Single `databricks_job` with per-table tasks kept **≤ 5 concurrent** (account limit).
- Dashboard/alerts run on the single **2X-Small** SQL warehouse.
