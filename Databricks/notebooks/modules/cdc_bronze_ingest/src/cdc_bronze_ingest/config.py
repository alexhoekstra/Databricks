"""Job configuration and path conventions for CDC bronze ingestion.

All values are supplied at run time (by a Databricks ``python_wheel_task`` or the
CLI) rather than hardcoded, so the same wheel ingests any DMS-replicated schema.
The path-building helpers are pure functions, which keeps them unit-testable
without a Spark session.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from typing import Sequence


@dataclass(frozen=True)
class IngestionConfig:
    """Resolved configuration for a single ingestion run.

    Attributes:
        s3_cdc_prefix:   S3 prefix DMS writes CDC Parquet under, e.g.
                         ``s3://bucket/dms-cdc``.
        source_schema:   Source MySQL database name, e.g. ``mydb``. DMS nests
                         per-table prefixes beneath ``<s3_cdc_prefix>/<schema>/``.
        target_catalog:  Unity Catalog catalog bronze tables are written to.
        target_schema:   Unity Catalog schema bronze tables are written to.
        checkpoint_base: S3 path for Auto Loader checkpoints and inferred schema.
        bronze_suffix:   Suffix appended to each source table name to form the
                         bronze table name (default ``_raw``).
    """

    s3_cdc_prefix: str
    source_schema: str
    target_catalog: str
    target_schema: str
    checkpoint_base: str
    bronze_suffix: str = "_raw"

    # -- Path conventions ----------------------------------------------------

    @property
    def source_root(self) -> str:
        """Prefix under which every replicated table for the schema lives."""
        return f"{self.s3_cdc_prefix}/{self.source_schema}"

    def source_path(self, table: str) -> str:
        """S3 path of the DMS Parquet files for ``table``."""
        return f"{self.source_root}/{table}/"

    def bronze_table(self, table: str) -> str:
        """Fully-qualified UC bronze table name for ``table``."""
        return f"{self.target_catalog}.{self.target_schema}.{table}{self.bronze_suffix}"

    def checkpoint_path(self, table: str) -> str:
        """Auto Loader checkpoint location for ``table``."""
        return f"{self.checkpoint_base}/{self.source_schema}/{table}"

    def schema_location(self, table: str) -> str:
        """Auto Loader inferred-schema storage location for ``table``."""
        return f"{self.checkpoint_base}/{self.source_schema}/{table}/_schema"

    # -- Construction --------------------------------------------------------

    @classmethod
    def from_args(cls, argv: Sequence[str] | None = None) -> "IngestionConfig":
        """Build a config from command-line arguments.

        A Databricks ``python_wheel_task`` passes ``named_parameters`` as
        ``--key value`` pairs, which argparse consumes directly.
        """
        parser = argparse.ArgumentParser(
            prog="cdc_bronze_ingest",
            description="Ingest DMS CDC Parquet files into bronze Delta tables via Auto Loader.",
        )
        parser.add_argument(
            "--s3_cdc_prefix",
            required=True,
            help="S3 prefix where DMS writes CDC Parquet, e.g. s3://bucket/dms-cdc",
        )
        parser.add_argument(
            "--source_schema",
            required=True,
            help="Source MySQL database name, e.g. mydb",
        )
        parser.add_argument(
            "--target_catalog",
            required=True,
            help="Unity Catalog catalog for bronze tables, e.g. main",
        )
        parser.add_argument(
            "--target_schema",
            required=True,
            help="Unity Catalog schema for bronze tables, e.g. lakeflow_staging",
        )
        parser.add_argument(
            "--checkpoint_base",
            required=True,
            help="S3 path for Auto Loader checkpoints, e.g. s3://bucket/checkpoints/cdc-bronze",
        )
        parser.add_argument(
            "--bronze_suffix",
            default="_raw",
            help="Suffix appended to source table names for bronze tables (default: _raw)",
        )
        args = parser.parse_args(argv)
        return cls(
            s3_cdc_prefix=args.s3_cdc_prefix,
            source_schema=args.source_schema,
            target_catalog=args.target_catalog,
            target_schema=args.target_schema,
            checkpoint_base=args.checkpoint_base,
            bronze_suffix=args.bronze_suffix,
        )
