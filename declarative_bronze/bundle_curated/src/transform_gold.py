# Databricks notebook source
"""Gold aggregate layer for declarative_curated.

Runs in the SAME pipeline as transform_silver.py (Free Edition allows only one
active pipeline update at a time, so a third pipeline is forbidden). Gold tables
are batch, materialized ``@dlt.table`` views recomputed each update from the
SCD2-current snapshot of the silver tables.

Three aggregates, one natural dashboard page each:

  - ``program_execution_gold``  — grain program_id: awards vs. obligations.
  - ``vendor_spend_gold``       — grain vendor_id: contract spend & concentration.
  - ``fy_appropriation_gold``   — grain fiscal_year x appropriation: budget trend.

Configuration (mirrors transform_silver.py — config is the SOLE source of truth,
NO spark.catalog probing):

    declarative_curated.silver_source   main.declarative_silver   # catalog.schema to read
    declarative_curated.gold_target     main.declarative_gold     # catalog.schema to publish

Both are supplied as ``catalog.schema`` strings resolved from the bundle's schema
resources, so they carry the dev-mode name prefix in the ``dev`` target (gold stays
dev-isolated) and the bare names in ``prod`` — the published
``main.declarative_gold.<name>`` contract data_quality reads. Cross-schema publish
(gold tables land in a schema other than the pipeline default silver schema) is a
direct-publishing-mode feature: this pipeline sets ``catalog`` + ``schema``.

Gold reads silver CURRENT rows only (``__END_AT IS NULL``) — never bronze, never
quarantine. Every table carries ``_computed_ts`` (F.current_timestamp()), the
freshness contract data_quality monitors.
"""

import dlt
from pyspark.sql import functions as F

# spark is provided by the DLT runtime.
SILVER_SOURCE: str = spark.conf.get("declarative_curated.silver_source", "")  # noqa: F821
GOLD_TARGET: str = spark.conf.get("declarative_curated.gold_target", "")  # noqa: F821

# Fail fast (mirror transform_silver.py): both locations are required.
if not SILVER_SOURCE:
    raise ValueError("declarative_curated.silver_source must be set in pipeline configuration")
if not GOLD_TARGET:
    raise ValueError("declarative_curated.gold_target must be set in pipeline configuration")


def _silver(name: str):  # noqa: ANN202
    """SCD2-CURRENT snapshot of a silver table (one row per key).

    DLT resolves this as an in-pipeline dependency from the read below and orders
    gold after silver in the same update. We do NOT probe with
    spark.catalog.tableExists() — it is not whitelisted in the DLT serverless
    runtime and raises Py4JSecurityException; a missing silver table surfaces
    through DLT's own dependency resolution instead.
    """
    return spark.read.table(f"{SILVER_SOURCE}.{name}_silver").where("__END_AT IS NULL")  # noqa: F821


@dlt.table(
    name=f"{GOLD_TARGET}.program_execution_gold",
    comment="Per-program execution: awards vs. obligations. Grain: program_id.",
    table_properties={"quality": "gold"},
)
def program_execution_gold():  # noqa: ANN202
    programs = _silver("programs")
    contracts = _silver("contracts")
    obligations = _silver("obligations")

    # Aggregate children per program BEFORE joining, so a program with N contracts
    # and M obligations stays exactly one row (a direct 3-way join would fan out
    # and double-count award/obligation amounts).
    contracts_agg = contracts.groupBy("program_id").agg(
        F.count(F.lit(1)).alias("contracts_count"),
        F.sum("award_amount").alias("total_awarded"),
        F.min(F.to_date("award_date")).alias("first_award_date"),
    )
    obligations_agg = obligations.groupBy("program_id").agg(
        F.sum("amount").alias("total_obligated"),
        F.max(F.to_date("obligated_date")).alias("latest_obligated_date"),
    )

    joined = programs.join(contracts_agg, "program_id", "left").join(
        obligations_agg, "program_id", "left"
    )
    # Left joins + coalesce: programs with no contracts/obligations show zeros.
    total_awarded = F.coalesce(F.col("total_awarded"), F.lit(0.0))
    total_obligated = F.coalesce(F.col("total_obligated"), F.lit(0.0))
    return joined.select(
        "program_id",
        "program_name",
        "branch",
        "status",
        F.coalesce(F.col("contracts_count"), F.lit(0)).alias("contracts_count"),
        total_awarded.alias("total_awarded"),
        total_obligated.alias("total_obligated"),
        # nullif(total_awarded, 0) guards divide-by-zero -> NULL rate.
        F.when(total_awarded == 0, None)
        .otherwise(F.round(F.lit(100) * total_obligated / total_awarded, 2))
        .alias("execution_rate_pct"),
        F.col("first_award_date"),
        F.col("latest_obligated_date"),
    ).withColumn("_computed_ts", F.current_timestamp())


@dlt.table(
    name=f"{GOLD_TARGET}.vendor_spend_gold",
    comment="Per-vendor contract spend & concentration. Grain: vendor_id.",
    table_properties={"quality": "gold"},
)
def vendor_spend_gold():  # noqa: ANN202
    vendors = _silver("vendors")
    contracts = _silver("contracts")

    contracts_agg = contracts.groupBy("vendor_id").agg(
        F.count(F.lit(1)).alias("contracts_count"),
        F.countDistinct("program_id").alias("programs_served"),
        F.sum("award_amount").alias("total_awarded"),
        F.avg("award_amount").alias("avg_award"),
        F.max("award_amount").alias("largest_award"),
    )
    return (
        vendors.join(contracts_agg, "vendor_id", "left")
        .select(
            "vendor_id",
            "vendor_name",
            "location",
            F.coalesce(F.col("contracts_count"), F.lit(0)).alias("contracts_count"),
            F.coalesce(F.col("programs_served"), F.lit(0)).alias("programs_served"),
            F.coalesce(F.col("total_awarded"), F.lit(0.0)).alias("total_awarded"),
            F.col("avg_award"),
            F.col("largest_award"),
        )
        .withColumn("_computed_ts", F.current_timestamp())
    )


@dlt.table(
    name=f"{GOLD_TARGET}.fy_appropriation_gold",
    comment="Obligations by fiscal year & appropriation. Grain: fiscal_year x appropriation.",
    table_properties={"quality": "gold"},
)
def fy_appropriation_gold():  # noqa: ANN202
    obligations = _silver("obligations")
    return (
        obligations.groupBy("fiscal_year", "appropriation")
        .agg(
            F.count(F.lit(1)).alias("obligations_count"),
            F.sum("amount").alias("total_obligated"),
            F.countDistinct("program_id").alias("programs_funded"),
            F.avg("amount").alias("avg_obligation"),
        )
        .withColumn("_computed_ts", F.current_timestamp())
    )
