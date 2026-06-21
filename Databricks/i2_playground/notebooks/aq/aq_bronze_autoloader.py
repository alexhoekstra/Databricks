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

year_glob  = "{" + ",".join(str(y) for y in range(start_year, dt.datetime.now().year + 1)) + "}"
location_glob = "{" + ",".join(str(lid) for lid in location_ids) + "}"
source_path = f"s3://openaq-data-archive/records/csv.gz/locationid={location_glob}/year={year_glob}/"

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
    .load(source_path)
)

(
    bronze_df.writeStream
    .format("delta")
    .outputMode("append")
    .option("checkpointLocation", f"{checkpoint_base}/bronze_openaq")
    .trigger(availableNow=True)
    .toTable(f"{catalog_name}.{schema_name}.bronze_openaq_raw")
)