"""Generic Auto Loader for scalable ingestion.

Streams data from cloud storage to Delta Lake with schema auto-detection.
"""
import json
from pathlib import Path
import pyspark.sql.functions as F

def get_format_from_filename(filename: str) -> str:
    """ Gets the format from the given filename """
    ext = Path(filename).suffix.lower().lstrip(".")

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


# Parameters injected by Databricks job
source_config = json.loads(dbutils.widgets.get("source_config"))
source_path = dbutils.widgets.get("source_path")
target = dbutils.widgets.get("target_table")

file_format = get_format_from_filename(source_config["filename"])

raw_df = None

if file_format == "csv":
    raw_df = (
        spark.read
        .format(file_format)
        .option("header", "true")
        .option("inferSchema", "true")
        .load(source_path + "/" + source_config["filename"])
    )

if raw_df is not None:
    bronze_df = (
        raw_df
        .withColumn("_ingest_timestamp", F.current_timestamp())
        .withColumn("_source_file", F.lit(source_path + "/" + source_config["filename"]))
    )

    (
        bronze_df.write
        .format("delta")
        .mode("append")
        .option("mergeSchema", "true")
        .saveAsTable(target)
    )
else:
    print("Format could not be parsed")
