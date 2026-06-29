"""Entry point: orchestrate CDC bronze ingestion for every discovered table.

Run as a Databricks ``python_wheel_task`` with ``entry_point = "cdc_bronze_ingest"``
(see ``[project.scripts]`` in pyproject.toml), or locally via
``python -m cdc_bronze_ingest.ingest --s3_cdc_prefix ... --source_schema ...``.
"""

from __future__ import annotations

import logging
from typing import Any, Sequence

from .config import IngestionConfig
from .discovery import discover_tables
from .streaming import stream_table_to_bronze

logger = logging.getLogger(__name__)


def run(spark: Any, dbutils: Any, config: IngestionConfig) -> list[str]:
    """Discover tables, start a stream for each, and wait for completion.

    Args:
        spark:   Active Spark session.
        dbutils: Databricks ``dbutils`` handle.
        config:  Resolved ingestion configuration.

    Returns:
        The list of tables whose streams started successfully.
    """
    logger.info("CDC source : %s/", config.source_root)
    logger.info("Target     : %s.%s", config.target_catalog, config.target_schema)
    logger.info("Checkpoints: %s", config.checkpoint_base)

    tables = discover_tables(dbutils, config)
    if not tables:
        logger.warning(
            "No tables found under %s/ — DMS may not have started yet.",
            config.source_root,
        )
        return []

    started: list[str] = []
    for table in tables:
        try:
            stream_table_to_bronze(spark, config, table)
            started.append(table)
        except Exception:  # one bad table must not abort the rest
            logger.exception("Failed to start stream for table %s", table)

    logger.info("Waiting for %d stream(s) to complete...", len(started))
    for query in spark.streams.active:
        query.awaitTermination()

    _log_summary(spark, config, started)
    return started


def _log_summary(spark: Any, config: IngestionConfig, tables: Sequence[str]) -> None:
    """Log per-table row counts and a CDC op breakdown after ingestion."""
    logger.info("=== BRONZE CDC INGESTION COMPLETE ===")
    for table in tables:
        bronze = config.bronze_table(table)
        try:
            df = spark.table(bronze)
            total = df.count()
            ops = df.groupBy("_op").count().collect()
            op_summary = ", ".join(f"{row['_op']}={row['count']}" for row in ops)
            logger.info("  %-25s %8d rows  [%s]", table, total, op_summary)
        except Exception as exc:
            logger.warning("  %-25s complete (summary unavailable: %s)", table, exc)


def main(argv: Sequence[str] | None = None) -> None:
    """Console entry point. Resolves Spark/dbutils from the runtime, then runs."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    # Imported lazily so the module is importable (and unit-testable) off-cluster.
    from databricks.sdk.runtime import spark, dbutils  # pylint: disable=import-outside-toplevel

    config = IngestionConfig.from_args(argv)
    run(spark, dbutils, config)


if __name__ == "__main__":
    main()
