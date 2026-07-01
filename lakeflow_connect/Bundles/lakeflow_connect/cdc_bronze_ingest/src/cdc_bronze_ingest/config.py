"""Job configuration and path conventions for CDC bronze ingestion.

All values are supplied at run time (by a Databricks ``python_wheel_task`` or the
CLI) rather than hardcoded, so the same wheel ingests any source. The path-building
helpers are pure functions, which keeps them unit-testable without a Spark session.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from typing import Sequence

# Conventional UC managed-volume name (under the target schema) used for Auto
# Loader checkpoints + inferred schema when --checkpoint_base is not supplied.
# This is an implicit contract with the deployment layer: the lakeflow_connect
# DAB creates a volume of this name under the bronze schema. Keep the two in sync.
DEFAULT_CHECKPOINT_VOLUME = "_checkpoints"


@dataclass(frozen=True)
class IngestionConfig:
    """Resolved configuration for a single ingestion run.

    Attributes:
        source_path:     URI of the directory whose immediate subdirectories are
                         the source tables, e.g. ``s3://bucket/dms-cdc/mydb``. Any
                         scheme works (``s3://``, ``abfss://``, ``gs://``).
        source_schema:   Source schema/database name, e.g. ``mydb`` — used for
                         lineage and checkpoint namespacing, not path discovery.
        target_catalog:  Unity Catalog catalog bronze tables are written to.
        target_schema:   Unity Catalog schema bronze tables are written to.
        checkpoint_base: Base URI for Auto Loader checkpoints and inferred schema.
                         When not supplied at parse time, defaults to the UC
                         managed volume
                         ``/Volumes/{target_catalog}/{target_schema}/_checkpoints``.
        bronze_suffix:   Suffix appended to each source table name to form the
                         bronze table name (default ``_raw``).
    """

    source_path: str
    source_schema: str
    target_catalog: str
    target_schema: str
    checkpoint_base: str
    bronze_suffix: str = "_raw"

    # -- Path conventions ----------------------------------------------------

    def table_path(self, table: str) -> str:
        """Source URI of the files for ``table`` (a subdirectory of source_path)."""
        return f"{self.source_path}/{table}/"

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
            description="Ingest CDC/source files into bronze Delta tables via Auto Loader.",
        )
        parser.add_argument(
            "--source_path",
            required=True,
            help="URI of the directory whose subdirectories are tables, e.g. s3://bucket/dms-cdc/mydb",
        )
        parser.add_argument(
            "--source_schema",
            required=True,
            help="Source schema/database name, e.g. mydb (used for lineage + checkpoints)",
        )
        parser.add_argument(
            "--target_catalog",
            required=True,
            help="Unity Catalog catalog for bronze tables, e.g. main",
        )
        parser.add_argument(
            "--target_schema",
            required=True,
            help="Unity Catalog schema for bronze tables, e.g. hr_bronze",
        )
        parser.add_argument(
            "--checkpoint_base",
            default=None,
            help=(
                "Base URI for Auto Loader checkpoints + inferred schema. Optional: "
                "if omitted, defaults to the UC managed volume "
                f"/Volumes/<target_catalog>/<target_schema>/{DEFAULT_CHECKPOINT_VOLUME}"
            ),
        )
        parser.add_argument(
            "--bronze_suffix",
            default="_raw",
            help="Suffix appended to source table names for bronze tables (default: _raw)",
        )
        args = parser.parse_args(argv)
        # Convention over configuration: default checkpoints to a UC managed
        # volume under the (already-resolved) target schema. target_schema may be
        # a dev-mode-prefixed name, which is exactly what we want the path to use.
        checkpoint_base = args.checkpoint_base or (
            f"/Volumes/{args.target_catalog}/{args.target_schema}/{DEFAULT_CHECKPOINT_VOLUME}"
        )
        return cls(
            source_path=args.source_path,
            source_schema=args.source_schema,
            target_catalog=args.target_catalog,
            target_schema=args.target_schema,
            checkpoint_base=checkpoint_base,
            bronze_suffix=args.bronze_suffix,
        )
