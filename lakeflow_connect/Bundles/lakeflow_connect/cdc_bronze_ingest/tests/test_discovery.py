"""Unit tests for table discovery, using a fake dbutils (no Spark needed)."""

from types import SimpleNamespace

from cdc_bronze_ingest.config import IngestionConfig
from cdc_bronze_ingest.discovery import discover_tables


def _file_info(name: str, is_dir: bool):
    """Mimic the FileInfo object returned by dbutils.fs.ls."""
    return SimpleNamespace(name=name, isDir=lambda: is_dir)


class FakeDbutils:
    def __init__(self, listing=None, raise_exc=None):
        self._listing = listing or []
        self._raise = raise_exc
        self.fs = SimpleNamespace(ls=self._ls)

    def _ls(self, _prefix):
        if self._raise:
            raise self._raise
        return self._listing


def make_config() -> IngestionConfig:
    return IngestionConfig(
        source_path="s3://bucket/dms-cdc/mydb",
        source_schema="mydb",
        target_catalog="main",
        target_schema="hr_bronze",
        checkpoint_base="s3://bucket/checkpoints",
    )


def test_discover_returns_sorted_directory_names():
    listing = [
        _file_info("orders/", True),
        _file_info("employees/", True),
        _file_info("_manifest.json", False),  # files are ignored
    ]
    tables = discover_tables(FakeDbutils(listing), make_config())
    assert tables == ["employees", "orders"]


def test_discover_missing_prefix_returns_empty():
    dbutils = FakeDbutils(raise_exc=Exception("path does not exist"))
    assert discover_tables(dbutils, make_config()) == []
