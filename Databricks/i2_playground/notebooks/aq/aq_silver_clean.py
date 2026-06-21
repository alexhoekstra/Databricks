from pyspark.sql import functions as F

dbutils.widgets.text("catalog_name", "main")
dbutils.widgets.text("schema_name", "openaq")
dbutils.widgets.text("openaq_location_ids", "")

catalog_name = dbutils.widgets.get("catalog_name")
schema_name  = dbutils.widgets.get("schema_name")
location_ids = [int(x) for x in dbutils.widgets.get("openaq_location_ids").split(",")]

bronze = spark.table(f"{catalog_name}.{schema_name}.bronze_openaq_raw")

silver_df = (
    bronze
    # ── Filter on original location_id before any transforms ───────
    .filter(F.col("location_id").isin(location_ids))
    # ── Drop duplicate locationid column (Auto Loader artifact) ────
    .drop("locationid")
    # ── Parse timestamps ───────────────────────────────────────────
    .withColumn("measured_at",    F.to_timestamp("datetime"))
    .withColumn("measured_date",  F.to_date("measured_at"))
    .withColumn("measured_year",  F.year("measured_at"))
    .withColumn("measured_month", F.month("measured_at"))
    # ── Cast value, drop nulls and negatives ───────────────────────
    .withColumn("value", F.col("value").cast("double"))
    .filter(F.col("value").isNotNull())
    .filter(F.col("value") >= 0)
    # ── Rename to clean column names ───────────────────────────────
    .withColumnRenamed("parameter",     "pollutant")
    .withColumnRenamed("units",         "unit")
    .withColumnRenamed("location", "location_name")
    .withColumnRenamed("lat",           "latitude")
    .withColumnRenamed("lon",           "longitude")
    # ── Drop raw datetime in favour of typed columns ───────────────
    .drop("datetime")
    # ── Deduplicate after all renames ──────────────────────────────
    .dropDuplicates(["location_id", "pollutant", "measured_at"])
)

(
    silver_df.write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .partitionBy("measured_year", "measured_month")
    .saveAsTable(f"{catalog_name}.{schema_name}.silver_openaq_clean")
)