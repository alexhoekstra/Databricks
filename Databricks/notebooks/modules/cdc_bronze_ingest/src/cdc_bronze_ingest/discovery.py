"""Discover the DMS-replicated tables present in S3.

DMS creates one prefix per replicated table beneath
``<s3_cdc_prefix>/<source_schema>/``. Listing that prefix tells us which tables
to ingest without hardcoding a table list — new tables appear automatically.
"""

from __future__ import annotations

import logging
from typing import Any

from .config import IngestionConfig

logger = logging.getLogger(__name__)


def discover_tables(dbutils: Any, config: IngestionConfig) -> list[str]:
    """Return the table prefixes under the schema's CDC root.

    Args:
        dbutils: The Databricks ``dbutils`` handle (used for ``fs.ls``).
        config:  Resolved ingestion configuration.

    Returns:
        Sorted list of table names. Empty if the prefix does not exist yet
        (e.g. DMS has not started writing), which is treated as a no-op rather
        than an error.
    """
    prefix = f"{config.source_root}/"
    try:
        items = dbutils.fs.ls(prefix)
    except Exception as exc:  # dbutils raises if the prefix doesn't exist yet
        logger.warning("Could not list %s: %s", prefix, exc)
        return []

    tables = sorted(item.name.rstrip("/") for item in items if item.isDir())
    logger.info("Discovered %d table(s) under %s: %s", len(tables), prefix, tables)
    return tables
