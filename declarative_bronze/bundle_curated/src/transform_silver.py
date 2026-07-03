# Databricks notebook source
"""Config-driven silver curation for declarative_curated.

Consumes bronze tables produced by ../../bundle (declarative_bronze) and builds,
per configured table:

  - `_<name>_clean`      — a view with expectations applied + a dedup guard,
  - `<name>_quarantine`  — a streaming table of expectation failures,
  - `<name>_silver`      — an SCD2 table via apply_changes (__START_AT/__END_AT).

Configuration is the SOLE source of truth — NO bucket discovery here:

    declarative_curated.source   main.declarative_bronze   # catalog.schema of bronze
    declarative_curated.tables   {json}                    # per-table silver config

Adding a silver table = add one JSON entry under declarative_curated.tables in
../resources/pipeline.yml and redeploy.

Gold (future): gold aggregates would join THIS pipeline as @dlt.table
materialized views over the silver tables — no third pipeline is needed.
"""

import json

import dlt
from pyspark.sql import functions as F

# spark is provided by the DLT runtime.
SOURCE: str = spark.conf.get("declarative_curated.source", "")  # noqa: F821
SILVER_CFG: dict = json.loads(spark.conf.get("declarative_curated.tables", "{}"))  # noqa: F821

# Fail fast (mirror the bronze pipeline's item-1 behavior): config is required.
if not SOURCE:
    raise ValueError("declarative_curated.source must be set in pipeline configuration")
if not SILVER_CFG:
    raise ValueError("declarative_curated.tables must be set (non-empty) in pipeline configuration")


def _define_silver(name: str, cfg: dict) -> None:
    """Clean view + quarantine table + SCD2 silver table for one source."""
    # DLT resolves this bronze dependency from readStream.table() below and fails
    # the update with a clear "table or view not found" error naming it when the
    # source is missing. We do NOT probe with spark.catalog.tableExists() — that
    # method is not whitelisted in the DLT (serverless) runtime and raises a
    # Py4JSecurityException.
    bronze_fqn = f"{SOURCE}.{name}_bronze"

    primary_keys: list = cfg["primary_keys"]
    sequence_by: str = cfg["sequence_by"]
    expectations: dict = cfg.get("expectations", {})

    clean_view = f"_{name}_clean"

    @dlt.view(name=clean_view, comment=f"Cleaned, de-duplicated {name} for apply_changes.")
    @dlt.expect_all_or_drop(expectations)
    def _clean():  # noqa: ANN202
        # dropDuplicates on primary_keys + sequence_by guards apply_changes against
        # same-key-same-sequence duplicates (e.g. _ingest_ts ties within a batch).
        return spark.readStream.table(bronze_fqn).dropDuplicates(  # noqa: F821
            primary_keys + [sequence_by]
        )

    # Quarantine: rows failing at least one expectation. Skip when no expectations.
    if expectations:
        not_all = " OR ".join(f"NOT ({cond})" for cond in expectations.values())

        @dlt.table(
            name=f"{name}_quarantine",
            comment=f"Rows from {name}_bronze that failed silver expectations.",
            table_properties={"quality": "quarantine"},
        )
        def _quarantine():  # noqa: ANN202
            return (
                spark.readStream.table(bronze_fqn)  # noqa: F821
                .where(not_all)
                .withColumn("_quarantined_ts", F.current_timestamp())
            )

    # SCD2 silver via apply_changes -> yields __START_AT / __END_AT, the columns
    # the data_quality SCD checks rely on.
    dlt.create_streaming_table(
        name=f"{name}_silver",
        comment=f"SCD2 silver for {name}.",
        table_properties={"quality": "silver"},
    )
    dlt.apply_changes(
        target=f"{name}_silver",
        source=clean_view,
        keys=primary_keys,
        sequence_by=F.col(sequence_by),
        stored_as_scd_type=2,
    )


for _name, _cfg in SILVER_CFG.items():
    _define_silver(_name, _cfg)
