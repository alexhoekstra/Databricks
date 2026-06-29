# Databricks notebook source
# notebooks/autoloader_cdc_bronze.py
#
# Auto Loader: DMS CDC Parquet files → Bronze Delta tables
#
# DMS writes CDC events to S3 as Parquet files under:
#   s3://<bucket>/dms-cdc/<schema>/<table>/YYYY/MM/DD/<timestamp>.parquet
#
# Each file row includes:
#   Op              — I (insert), U (update), D (delete)
#   <source columns> — all columns from the MySQL table
#
# This notebook:
#   1. Discovers all table prefixes under the DMS CDC path
#   2. Starts one Auto Loader stream per table
#   3. Appends to bronze Delta tables with CDC metadata columns
#   4. Runs in triggered mode — each job run processes all files
#      landed since the last checkpoint, then stops
#
# Bronze tables are append-only CDC logs. The Op column is preserved
# so silver/gold layers can correctly apply inserts, updates, and deletes.
#
# Parameters injected by Databricks Job:
#   s3_cdc_prefix   — S3 prefix where DMS writes (e.g. s3://bucket/dms-cdc)
#   source_schema   — MySQL database name (e.g. mydb)
#   target_catalog  — UC catalog (e.g. main)
#   target_schema   — UC schema (e.g. lakeflow_staging)
#   checkpoint_base — S3 path for Auto Loader checkpoints

from pyspark.sql import functions as F
from pyspark.sql.types import StringType
import re

# ==============================================================================
# PARAMETERS
# ==============================================================================

dbutils.widgets.text("s3_cdc_prefix",   "s3://<your-bucket>/dms-cdc")
dbutils.widgets.text("source_schema",   "mydb")
dbutils.widgets.text("target_catalog",  "main")
dbutils.widgets.text("target_schema",   "lakeflow_staging")
dbutils.widgets.text("checkpoint_base", "s3://<your-bucket>/checkpoints/cdc-bronze")

S3_CDC_PREFIX   = dbutils.widgets.get("s3_cdc_prefix")
SOURCE_SCHEMA   = dbutils.widgets.get("source_schema")
TARGET_CATALOG  = dbutils.widgets.get("target_catalog")
TARGET_SCHEMA   = dbutils.widgets.get("target_schema")
CHECKPOINT_BASE = dbutils.widgets.get("checkpoint_base")

print(f"CDC source : {S3_CDC_PREFIX}/{SOURCE_SCHEMA}/")
print(f"Target     : {TARGET_CATALOG}.{TARGET_SCHEMA}")
print(f"Checkpoints: {CHECKPOINT_BASE}")

# ==============================================================================
# HELPERS
# ==============================================================================

def bronze_table(table: str) -> str:
    return f"{TARGET_CATALOG}.{TARGET_SCHEMA}.{table}_raw"

def checkpoint_path(table: str) -> str:
    return f"{CHECKPOINT_BASE}/{SOURCE_SCHEMA}/{table}"

def schema_hints_path(table: str) -> str:
    """Auto Loader schema inference storage location."""
    return f"{CHECKPOINT_BASE}/{SOURCE_SCHEMA}/{table}/_schema"

def discover_tables() -> list[str]:
    """
    List table prefixes under s3://<bucket>/dms-cdc/<schema>/
    Each subdirectory is a table DMS is replicating.
    Returns [] if the prefix doesn't exist yet (DMS hasn't started).
    """
    try:
        prefix = f"{S3_CDC_PREFIX}/{SOURCE_SCHEMA}/"
        items  = dbutils.fs.ls(prefix)
        tables = [i.name.rstrip("/") for i in items if i.isDir()]
        return tables
    except Exception as e:
        print(f"  Could not list {S3_CDC_PREFIX}/{SOURCE_SCHEMA}/: {e}")
        return []

# ==============================================================================
# AUTO LOADER STREAM — one per table
#
# Uses cloudFiles (Auto Loader) to:
#   - Track exactly which files have been processed via checkpoints
#   - Automatically discover new files as DMS writes them
#   - Infer schema from Parquet files (no hardcoding needed)
#   - Handle schema evolution with mergeSchema
#
# Triggered mode (Trigger.Once) processes all available files then stops.
# This is correct for a scheduled job — continuous mode would keep the
# stream running indefinitely.
#
# The Op column from DMS maps to:
#   I → new row inserted in MySQL
#   U → existing row updated in MySQL
#   D → row deleted in MySQL
# ==============================================================================

def stream_table_to_bronze(table: str) -> None:
    source_path = f"{S3_CDC_PREFIX}/{SOURCE_SCHEMA}/{table}/"
    bronze      = bronze_table(table)
    checkpoint  = checkpoint_path(table)
    schema_loc  = schema_hints_path(table)

    print(f"  [{table}] Reading from {source_path}")
    print(f"  [{table}] Writing to  {bronze}")
    print(f"  [{table}] Checkpoint  {checkpoint}")

    stream = (
        spark.readStream
             .format("cloudFiles")
             .option("cloudFiles.format", "parquet")

             # Auto Loader infers schema from the Parquet files themselves
             # and stores it at schema_loc so it's consistent across runs
             .option("cloudFiles.inferColumnTypes",    "true")
             .option("cloudFiles.schemaLocation",      schema_loc)
             .option("cloudFiles.schemaEvolutionMode", "addNewColumns")

             # Include file metadata so we know exactly which DMS file
             # each row came from — useful for debugging and reprocessing
             .option("cloudFiles.includeExistingFiles", "true")

             .load(source_path)

             # Rename DMS Op column to _op for consistency with CDC conventions
             # Op values: I = insert, U = update, D = delete
             .withColumnRenamed("Op", "_op")

             # Add ingestion metadata
             .withColumn("_ingested_at",  F.current_timestamp())
             .withColumn("_source_file",  F.col("_metadata.file_path"))
             .withColumn("_source_table", F.lit(f"{SOURCE_SCHEMA}.{table}"))
    )

    (
        stream.writeStream
              .format("delta")
              .outputMode("append")
              .option("checkpointLocation", checkpoint)
              .option("mergeSchema", "true")

              # Triggered once — process all pending files then stop
              # Change to trigger(processingTime="1 minute") for near-real-time
              .trigger(once=True)

              .toTable(bronze)
    )

    print(f"  [{table}] Stream started (triggered once)")


# ==============================================================================
# MAIN
# ==============================================================================

tables = discover_tables()

if not tables:
    print("No tables found under CDC prefix — DMS may not have started yet.")
    print(f"Expected path: {S3_CDC_PREFIX}/{SOURCE_SCHEMA}/")
    dbutils.notebook.exit("NO_TABLES_FOUND")

print(f"\nDiscovered {len(tables)} tables: {tables}\n")

# Start all streams
active_streams = []
for table in tables:
    print(f"\n{'='*60}")
    print(f"Table: {table}")
    print(f"{'='*60}")
    try:
        stream_table_to_bronze(table)
        active_streams.append(table)
    except Exception as e:
        print(f"  ERROR starting stream for {table}: {e}")

# Wait for all triggered streams to finish processing
print(f"\nWaiting for {len(active_streams)} stream(s) to complete...")
for stream in spark.streams.active:
    stream.awaitTermination()

# Summary
print(f"\n{'='*60}")
print("BRONZE CDC INGESTION COMPLETE")
print(f"{'='*60}")
for table in active_streams:
    try:
        count = spark.table(bronze_table(table)).count()
        ops   = (spark.table(bronze_table(table))
                      .groupBy("_op")
                      .count()
                      .collect())
        op_summary = ", ".join(f"{r['_op']}={r['count']}" for r in ops)
        print(f"  ✓ {table:25s} {count:>8} total rows  [{op_summary}]")
    except Exception as e:
        print(f"  ✓ {table:25s} complete (count error: {e})")
