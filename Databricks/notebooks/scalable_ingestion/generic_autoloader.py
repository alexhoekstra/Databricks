"""Generic Auto Loader for scalable ingestion.

Streams data from cloud storage to Delta Lake with schema auto-detection.
"""
import json
from pathlib import Path
import pyspark.sql.functions as F

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
    """ Returns the absolute path of the first match, or None. 
    rglob includes parent directories if you include them as well as search parameters"""
    for path in Path(directory).rglob(searchfile):
        return path.resolve()
    return None

# Parameters injected by Databricks job
source_config = json.loads(dbutils.widgets.get("source_config"))
source_path = dbutils.widgets.get("source_path")
schema = dbutils.widgets.get("schema")
catalog = dbutils.widgets.get("catalog")

for filename in source_config["filenames"]:

    file_format = get_format_from_filename(filename["name"])

    ingest_file = find_file(source_path, filename["name"])

    print(ingest_file)

    raw_df = (
        spark.read
        .format(file_format)
        .option("header", "true")
        .option("inferSchema", "true")
        .load(source_path + "/" + filename["name"])
    )

    bronze_df = (
        raw_df
        .withColumn("_ingest_timestamp", F.current_timestamp())
        .withColumn("_source_file", F.lit(source_path + "/" + filename["name"]))
    )

    (
        bronze_df.write
        .format("delta")
        .mode("append")
        .option("mergeSchema", "true")
        .saveAsTable(catalog + "." + schema + "." + filename["table"])
    )
