"""This notebook ingests OpenAQ data from S3 using AutoLoader and writes it to 
a Delta Lake table in append mode. The source data is partitioned by location ID and year, 
and the notebook is parameterized to allow for flexible ingestion based on user input."""

import datetime as dt

dbutils.widgets.text("location_ids", "")
dbutils.widgets.text("start_year",   dt.datetime.now().year - 1)
dbutils.widgets.text("catalog_name", "main")
dbutils.widgets.text("schema_name",  "openaq")
dbutils.widgets.text("checkpoint_base", "/Volumes/main/openaq/checkpoints")

location_ids = [int(x) for x in dbutils.widgets.get("location_ids").split(",")]
start_year   = int(dbutils.widgets.get("start_year"))
catalog_name = dbutils.widgets.get("catalog_name")
schema_name  = dbutils.widgets.get("schema_name")
checkpoint_base = dbutils.widgets.get("checkpoint_base")

YEAR_GLOB  = "{" + ",".join(str(y) for y in range(start_year, dt.datetime.now().year + 1)) + "}"
LOCATION_GLOB = "{" + ",".join(str(lid) for lid in location_ids) + "}"
SOURCE_PATH = f"s3://openaq-data-archive/records/csv.gz/locationid={LOCATION_GLOB}/year={YEAR_GLOB}/"

bronze_df = (
    spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "csv")
    .option("cloudFiles.schemaLocation", f"{checkpoint_base}/schema_hints")
    .option("cloudFiles.inferColumnTypes", "true")
    .option("cloudFiles.useNotifications", "false")
    .option("header", "true")
    .option("fs.s3a.aws.credentials.provider",
            "org.apache.hadoop.fs.s3a.AnonymousAWSCredentialsProvider")
    .load(SOURCE_PATH)
)

(
    bronze_df.writeStream
    .format("delta")
    .outputMode("append")
    .option("checkpointLocation", f"{checkpoint_base}/bronze_openaq")
    .trigger(availableNow=True)
    .toTable(f"{catalog_name}.{schema_name}.bronze_openaq_raw")
)
