"""Unit tests for IngestionConfig path conventions and argument parsing."""

import pytest

from cdc_bronze_ingest.config import IngestionConfig


def make_config(**overrides) -> IngestionConfig:
    defaults = dict(
        source_path="s3://bucket/dms-cdc/mydb",
        source_schema="mydb",
        target_catalog="main",
        target_schema="hr_bronze",
        checkpoint_base="s3://bucket/checkpoints/hr",
    )
    defaults.update(overrides)
    return IngestionConfig(**defaults)


def test_table_path():
    cfg = make_config()
    assert cfg.table_path("employees") == "s3://bucket/dms-cdc/mydb/employees/"


def test_table_path_any_scheme():
    cfg = make_config(source_path="abfss://c@acct.dfs.core.windows.net/hr")
    assert cfg.table_path("dept") == "abfss://c@acct.dfs.core.windows.net/hr/dept/"


def test_bronze_table_default_suffix():
    cfg = make_config()
    assert cfg.bronze_table("employees") == "main.hr_bronze.employees_raw"


def test_bronze_table_custom_suffix():
    cfg = make_config(bronze_suffix="_bronze")
    assert cfg.bronze_table("employees") == "main.hr_bronze.employees_bronze"


def test_checkpoint_and_schema_paths():
    cfg = make_config()
    assert cfg.checkpoint_path("employees") == "s3://bucket/checkpoints/hr/mydb/employees"
    assert cfg.schema_location("employees") == "s3://bucket/checkpoints/hr/mydb/employees/_schema"


def test_from_args_parses_named_parameters():
    cfg = IngestionConfig.from_args([
        "--source_path", "s3://b/dms-cdc/hr",
        "--source_schema", "hr",
        "--target_catalog", "main",
        "--target_schema", "hr_bronze",
        "--checkpoint_base", "s3://b/checkpoints",
    ])
    assert cfg.source_schema == "hr"
    assert cfg.source_path == "s3://b/dms-cdc/hr"
    assert cfg.bronze_suffix == "_raw"  # default applied
    assert cfg.bronze_table("dept") == "main.hr_bronze.dept_raw"


def test_from_args_defaults_checkpoint_base_to_uc_volume():
    # checkpoint_base is optional: when omitted it defaults to a UC managed
    # volume under the target schema (convention shared with the DAB layer).
    cfg = IngestionConfig.from_args([
        "--source_path", "s3://b/dms-cdc/hr",
        "--source_schema", "hr",
        "--target_catalog", "main",
        "--target_schema", "hr_bronze",
    ])
    assert cfg.checkpoint_base == "/Volumes/main/hr_bronze/_checkpoints"
    assert cfg.checkpoint_path("dept") == "/Volumes/main/hr_bronze/_checkpoints/hr/dept"


def test_from_args_requires_mandatory_arguments():
    with pytest.raises(SystemExit):
        IngestionConfig.from_args(["--source_schema", "hr"])
