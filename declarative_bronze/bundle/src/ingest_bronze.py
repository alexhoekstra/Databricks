# Databricks notebook source
"""Generic Lakeflow Declarative Pipeline (DLT) source for declarative_bronze.

One pipeline that is configuration driven.

    declarative_bronze.path     s3://<bucket>   # shared landing root
    declarative_bronze.format   parquet         # one cloudFiles.format for every table

The table set is always DISCOVERED at build time by listing the landing root and
taking one table per distinct file stem (programs.parquet -> programs).

Run mode (triggered vs continuous) is set on the pipeline resource
(`continuous` field, from var.continuous) — the same code powers both.
"""

import dlt
from pyspark.sql import functions as F

# spark is provided by the DLT runtime.
DOMAIN_PATH: str = spark.conf.get("declarative_bronze.path", "")  # noqa: F821
DOMAIN_FORMAT: str = spark.conf.get("declarative_bronze.format", "parquet")  # noqa: F821


def _discover_tables() -> dict:
    """Discover the table set by listing the shared landing root."""
    if not DOMAIN_PATH:
        return {}
    try:
        listing = (
            spark.read.format("binaryFile")  # noqa: F821
            .option("recursiveFileLookup", "true")
            .option("pathGlobFilter", f"*.{DOMAIN_FORMAT}")
            .load(DOMAIN_PATH)
            .select(F.regexp_extract("path", r"([^/]+)\.[^./]+$", 1).alias("stem"))
            .where("stem <> ''")
            .distinct()
        )
        return {row.stem: {"glob": f"{row.stem}.{DOMAIN_FORMAT}"} for row in listing.collect()}
    except Exception:  # noqa: BLE001  (empty/absent path -> define nothing)
        return {}


TABLES: dict = _discover_tables()


def _define_bronze(name: str, cfg: dict) -> None:
    """Append-only raw bronze streaming table."""

    @dlt.table(
        name=f"{name}_bronze",
        comment=f"Raw append-only bronze for {name} (Auto Loader).",
        table_properties={"quality": "bronze"},
    )
    def _bronze():  # noqa: ANN202  
        return (
            spark.readStream.format("cloudFiles")  # noqa: F821
            .option("cloudFiles.format", DOMAIN_FORMAT)
            .option("cloudFiles.inferColumnTypes", "true")
            .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
            .option("cloudFiles.partitionColumns", "")
            .option("pathGlobFilter", cfg["glob"])   
            .load(DOMAIN_PATH)
            .withColumn("_ingest_ts", F.current_timestamp())
            .withColumn("_source_file", F.col("_metadata.file_path"))
            .withColumn("_source_name", F.lit(name))
        )


for _name, _cfg in TABLES.items():
    _define_bronze(_name, _cfg)
