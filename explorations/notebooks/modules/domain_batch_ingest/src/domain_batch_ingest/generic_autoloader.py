""" Configuration driven auto-loader to load data into tables """
import argparse
import json
from pathlib import Path
import pyspark.sql.functions as F

def get_format_from_filename(fname: str) -> str:
    """ Gets the format from the given filename """
    ext = Path(fname).suffix.lower().lstrip(".")
    format_map = {
        "json": "json", "csv": "csv", "parquet": "parquet",
        "pqt": "parquet", "avro": "avro", "txt": "text",
        "text": "text", "orc": "orc", "xml": "xml"
    }
    return format_map.get(ext, "binaryFile")

def find_file(directory, searchfile):
    """Returns the absolute path of the first match, or None."""
    for path in Path(directory).rglob(searchfile):
        return path.resolve()
    return None

def find_all_files(directory, searchfile):
    """Returns all resolved paths matching the pattern."""
    return [p.resolve() for p in Path(directory).rglob(searchfile)]

def is_wildcard(name: str) -> bool:
    """Returns True if the filename contains a wildcard character."""
    return any(c in name for c in ["*", "?", "[", "]"])

def get_files_to_ingest(directory, searchfile) -> list:
    """Returns a list of files to ingest, handling both wildcard and exact matches."""
    if is_wildcard(searchfile):
        return find_all_files(directory, searchfile)
    match = find_file(directory, searchfile)
    return [match] if match else []

def main():
    """ Entry point for the python wheel"""
    from databricks.sdk.runtime import spark # pylint: disable=import-outside-toplevel
    
    parser = argparse.ArgumentParser()
    parser.add_argument("--source_config", required=True)
    parser.add_argument("--source_path", required=True)
    parser.add_argument("--schema", required=True)
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--mode", required=True)
    args = parser.parse_args()
    
    source_config = json.loads(args.source_config)
    source_path = args.source_path
    schema = args.schema
    catalog = args.catalog
    mode = args.mode

    for filename in source_config["filenames"]:
        file_format = get_format_from_filename(filename["name"])
        files = get_files_to_ingest(source_path, filename["name"])

        if not files:
            print(f"No files found matching {filename['name']} in {source_path}, skipping.")
            continue

        print(f"Found {len(files)} file(s) for {filename['name']}: {files}")

        raw_df = (
            spark.read
            .format(file_format)
            .option("header", "true")
            .option("inferSchema", "true")
            .load([str(f) for f in files])
        )

        bronze_df = (
            raw_df
            .withColumn("_ingest_timestamp", F.current_timestamp())
            .withColumn("_source_file", F.col("_metadata.file_path"))
        )

        (
            bronze_df.write
            .format("delta")
            .mode(mode)
            .option("mergeSchema", "true")
            .saveAsTable(f"{catalog}.{schema}.{filename['table']}")
        )
