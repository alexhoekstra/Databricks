"""Unit tests for IngestionConfig path conventions and argument parsing."""

import pytest

from cdc_bronze_ingest.config import IngestionConfig


def make_config(**overrides) -> IngestionConfig:
    defaults = dict(
        s3_cdc_prefix="s3://bucket/dms-cdc",
        source_schema="mydb",
        target_catalog="main",
        target_schema="lakeflow_staging",
        checkpoint_base="s3://bucket/checkpoints/cdc-bronze",
    )
    defaults.update(overrides)
    return IngestionConfig(**defaults)


def test_source_root():
    cfg = make_config()
    assert cfg.source_root == "s3://bucket/dms-cdc/mydb"


def test_source_path():
    cfg = make_config()
    assert cfg.source_path("employees") == "s3://bucket/dms-cdc/mydb/employees/"


def test_bronze_table_default_suffix():
    cfg = make_config()
    assert cfg.bronze_table("employees") == "main.lakeflow_staging.employees_raw"


def test_bronze_table_custom_suffix():
    cfg = make_config(bronze_suffix="_bronze")
    assert cfg.bronze_table("employees") == "main.lakeflow_staging.employees_bronze"


def test_checkpoint_and_schema_paths():
    cfg = make_config()
    assert cfg.checkpoint_path("employees") == "s3://bucket/checkpoints/cdc-bronze/mydb/employees"
    assert cfg.schema_location("employees") == "s3://bucket/checkpoints/cdc-bronze/mydb/employees/_schema"


def test_from_args_parses_named_parameters():
    cfg = IngestionConfig.from_args([
        "--s3_cdc_prefix", "s3://b/dms-cdc",
        "--source_schema", "hr",
        "--target_catalog", "main",
        "--target_schema", "staging",
        "--checkpoint_base", "s3://b/checkpoints",
    ])
    assert cfg.source_schema == "hr"
    assert cfg.bronze_suffix == "_raw"  # default applied
    assert cfg.bronze_table("dept") == "main.staging.dept_raw"


def test_from_args_requires_mandatory_arguments():
    with pytest.raises(SystemExit):
        IngestionConfig.from_args(["--source_schema", "hr"])
