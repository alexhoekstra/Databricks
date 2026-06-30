"""Auto Loader stream: one DMS CDC table -> one bronze Delta table.

Each DMS Parquet row carries an ``Op`` column (I = insert, U = update,
D = delete) plus the source columns. Bronze tables are append-only CDC logs:
the ``Op`` value is preserved (renamed ``_op``) so downstream silver/gold layers
can correctly replay inserts, updates, and deletes.
"""

from __future__ import annotations

import logging
from typing import Any

from pyspark.sql import functions as F

from .config import IngestionConfig

logger = logging.getLogger(__name__)


def stream_table_to_bronze(spark: Any, config: IngestionConfig, table: str) -> None:
    """Start a triggered Auto Loader stream for a single table.

    The stream runs in ``availableNow`` mode: it processes every file landed
    since the last checkpoint, then stops — the correct semantics for a
    scheduled batch job. Switch to ``trigger(processingTime=...)`` for
    near-real-time ingestion.

    Args:
        spark:  Active Spark session.
        config: Resolved ingestion configuration.
        table:  Source table name (a prefix discovered under the CDC root).
    """
    source_path = config.table_path(table)
    bronze = config.bronze_table(table)
    checkpoint = config.checkpoint_path(table)
    schema_loc = config.schema_location(table)

    logger.info("[%s] reading from %s", table, source_path)
    logger.info("[%s] writing to   %s", table, bronze)
    logger.info("[%s] checkpoint   %s", table, checkpoint)

    stream = (
        spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "parquet")
        # Auto Loader infers schema from the Parquet files and persists it at
        # schema_loc so it stays consistent across runs.
        .option("cloudFiles.inferColumnTypes", "true")
        .option("cloudFiles.schemaLocation", schema_loc)
        .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
        .option("cloudFiles.includeExistingFiles", "true")
        .load(source_path)
        # Rename the DMS Op column to _op (I = insert, U = update, D = delete).
        .withColumnRenamed("Op", "_op")
        # Ingestion lineage metadata.
        .withColumn("_ingested_at", F.current_timestamp())
        .withColumn("_source_file", F.col("_metadata.file_path"))
        .withColumn("_source_table", F.lit(f"{config.source_schema}.{table}"))
    )

    (
        stream.writeStream
        .format("delta")
        .outputMode("append")
        .option("checkpointLocation", checkpoint)
        .option("mergeSchema", "true")
        # Process all pending files then stop.
        .trigger(availableNow=True)
        .toTable(bronze)
    )

    logger.info("[%s] stream started (availableNow)", table)
