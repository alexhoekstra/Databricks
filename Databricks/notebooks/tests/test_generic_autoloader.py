""" Unit tests for ../modules/domain_batch_ingest"""
# pylint: disable=E0401
# pylint: disable=C0116
import sys
import types
from pathlib import Path
from domain_batch_ingest import generic_autoloader
import pytest

MODULE_ROOT = Path(__file__).resolve().parents[1] / "modules" / "domain_batch_ingest" / "src"
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

if "pyspark" not in sys.modules:
    pyspark_module = types.ModuleType("pyspark")
    sql_module = types.ModuleType("pyspark.sql")
    functions_module = types.ModuleType("pyspark.sql.functions")
    functions_module.current_timestamp = lambda: None  # type: ignore
    functions_module.col = lambda *args, **kwargs: None  # type: ignore
    sql_module.functions = functions_module  # type: ignore
    pyspark_module.sql = sql_module  # type: ignore
    sys.modules["pyspark"] = pyspark_module
    sys.modules["pyspark.sql"] = sql_module
    sys.modules["pyspark.sql.functions"] = functions_module




@pytest.mark.parametrize(
    ("filename", "expected"),
    [
        ("sales.json", "json"),
        ("sales.CSV", "csv"),
        ("sales.pqt", "parquet"),
        ("sales.bin", "binaryFile"),
    ],
)
def test_get_format_from_filename_returns_expected_format(filename, expected):
    assert generic_autoloader.get_format_from_filename(filename) == expected


def test_find_file_returns_resolved_path_for_exact_match(tmp_path):
    target = tmp_path / "nested" / "sample.csv"
    target.parent.mkdir(parents=True)
    target.write_text("a,b\n1,2\n")

    result = generic_autoloader.find_file(tmp_path, "sample.csv")

    assert result == target.resolve()


def test_find_all_files_returns_all_matching_paths(tmp_path):
    first = tmp_path / "one.csv"
    second = tmp_path / "nested" / "two.csv"
    second.parent.mkdir(parents=True)
    first.write_text("value")
    second.write_text("value")

    results = generic_autoloader.find_all_files(tmp_path, "*.csv")

    assert [path.name for path in results] == ["one.csv", "two.csv"]
    assert all(path.is_absolute() for path in results)


def test_get_files_to_ingest_handles_exact_and_wildcard_matches(tmp_path):
    target = tmp_path / "data.json"
    target.write_text("{}")

    wildcard_matches = generic_autoloader.get_files_to_ingest(tmp_path, "*.json")
    exact_matches = generic_autoloader.get_files_to_ingest(tmp_path, "data.json")

    assert wildcard_matches == [target.resolve()]
    assert exact_matches == [target.resolve()]


def test_get_files_to_ingest_returns_empty_when_nothing_matches(tmp_path):
    assert generic_autoloader.get_files_to_ingest(tmp_path, "missing.csv") == []
