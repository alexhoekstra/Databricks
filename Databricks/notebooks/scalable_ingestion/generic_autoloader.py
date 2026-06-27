"""Generic Auto Loader for scalable ingestion.

Streams data from cloud storage to Delta Lake with schema auto-detection.
"""
import json
from pathlib import Path
import pyspark.sql.functions as F

# Parameters injected by Databricks job
source_config = json.loads(dbutils.widgets.get("source_config"))
source_path = dbutils.widgets.get("source_path")
schema = dbutils.widgets.get("schema")
catalog = dbutils.widgets.get("catalog")

def get_format_from_filename(fname: str) -> str:
    """ Gets the format from the given filename """
    ext = Path(fname).suffix.lower().lstrip(".")

    # Map multiple extensions to your specific target types
    format_map = {
        "json": "json",
        "csv": "csv",
        "parquet": "parquet",
        "pqt": "parquet",      # Alternative parquet extension
        "avro": "avro",
        "txt": "text",         # Standard text files
        "text": "text",        # Alternative text naming
        "orc": "orc",
        "xml": "xml"
    }

    # Return matched format, or default to binaryFile
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
    else:
        match = find_file(directory, searchfile)
        return [match] if match else []


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
        .mode("append")
        .option("mergeSchema", "true")
        .saveAsTable(catalog + "." + schema + "." + filename["table"])
    )
