# Databricks notebook source
"""Generic Lakeflow Declarative Pipeline (DLT) source for declarative_bronze.

One pipeline that is configuration driven.

    declarative_bronze.path            s3://<bucket>   # shared landing root
    declarative_bronze.format          parquet         # one cloudFiles.format for every table
    declarative_bronze.fail_on_empty   true            # raise (vs. warn) when discovery finds nothing
    declarative_bronze.include_tables  ""              # optional CSV allow-list of stems
    declarative_bronze.exclude_tables  ""              # optional CSV deny-list of stems (wins over include)

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
FAIL_ON_EMPTY: str = spark.conf.get("declarative_bronze.fail_on_empty", "true")  # noqa: F821
# Optional allow/deny filter (comma-separated stems; empty = no filtering).
INCLUDE_TABLES: str = spark.conf.get("declarative_bronze.include_tables", "")  # noqa: F821
EXCLUDE_TABLES: str = spark.conf.get("declarative_bronze.exclude_tables", "")  # noqa: F821


def _csv_set(value: str) -> set:
    """Parse a comma-separated config string into a set of trimmed, non-empty stems."""
    return {s.strip() for s in value.split(",") if s.strip()}


def _discover_tables() -> dict:
    """Discover the table set by listing the shared landing root.

    Fails loudly instead of silently returning nothing: a missing path is a
    config error, and a broken credential / unreachable bucket must fail the
    update rather than run green with zero tables (silent data loss).

    An optional include/exclude filter keeps stray files (typos, test artifacts)
    from silently becoming permanent bronze tables. Exclude wins over include.
    """
    if not DOMAIN_PATH:
        raise ValueError("declarative_bronze.path must be set in pipeline configuration")
    listing = (
        spark.read.format("binaryFile")  # noqa: F821
        .option("recursiveFileLookup", "true")
        .option("pathGlobFilter", f"*.{DOMAIN_FORMAT}")
        .load(DOMAIN_PATH)
        .select(F.regexp_extract("path", r"([^/]+)\.[^./]+$", 1).alias("stem"))
        .where("stem <> ''")
        .distinct()
    )
    include = _csv_set(INCLUDE_TABLES)
    exclude = _csv_set(EXCLUDE_TABLES)
    return {
        row.stem: {"glob": f"{row.stem}.{DOMAIN_FORMAT}"}
        for row in listing.collect()
        if (not include or row.stem in include) and row.stem not in exclude
    }


TABLES: dict = _discover_tables()

if not TABLES:
    if FAIL_ON_EMPTY.lower() == "true":
        raise RuntimeError(
            f"Discovery found no *.{DOMAIN_FORMAT} files under {DOMAIN_PATH!r}; refusing to "
            "define zero tables. Set declarative_bronze.fail_on_empty=false to allow an empty "
            "run (bootstrap only)."
        )
    print(  # noqa: T201  (surfaces in the pipeline update log)
        f"WARNING: no *.{DOMAIN_FORMAT} files under {DOMAIN_PATH!r} and "
        "declarative_bronze.fail_on_empty=false; defining no tables."
    )


def _define_bronze(name: str, cfg: dict) -> None:
    """Append-only raw bronze streaming table."""

    @dlt.table(
        name=f"{name}_bronze",
        comment=f"Raw append-only bronze for {name} (Auto Loader).",
        # reset.allowed=false: bronze is the append-only system of record; block
        # full refresh, which would rebuild it from whatever files still exist in
        # the landing bucket (history loss if files were aged out). Silver/
        # quarantine are recomputable from bronze, so they omit this.
        table_properties={"quality": "bronze", "pipelines.reset.allowed": "false"},
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
            # Data recency (which business date landed), from the dated landing
            # folder s3://<bucket>/<DATE>/<table>.parquet. Nullable-safe: files not
            # under a dated folder miss the regexp -> "" -> to_date -> NULL.
            .withColumn(
                "_batch_date",
                F.to_date(
                    F.regexp_extract(F.col("_metadata.file_path"), r"/(\d{4}-\d{2}-\d{2})/[^/]+$", 1)
                ),
            )
        )


for _name, _cfg in TABLES.items():
    _define_bronze(_name, _cfg)
