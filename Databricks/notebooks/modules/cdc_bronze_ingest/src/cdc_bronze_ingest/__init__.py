"""Auto Loader ingestion of DMS CDC Parquet files into bronze Delta tables.

Public API:
    IngestionConfig        — parsed job configuration and path helpers
    discover_tables        — list the table prefixes DMS has written to S3
    stream_table_to_bronze — start one Auto Loader stream for a single table
    run                    — orchestrate discovery + streaming for all tables
"""

from .config import IngestionConfig
from .discovery import discover_tables
from .streaming import stream_table_to_bronze
from .ingest import run

__all__ = [
    "IngestionConfig",
    "discover_tables",
    "stream_table_to_bronze",
    "run",
]

__version__ = "0.1.0"
