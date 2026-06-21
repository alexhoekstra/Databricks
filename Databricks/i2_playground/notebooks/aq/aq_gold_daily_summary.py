"""AQ Gold Daily Summary Notebook"""

from pyspark.sql import functions as F

dbutils.widgets.text("catalog_name", "main")
dbutils.widgets.text("schema_name", "openaq")

catalog_name = dbutils.widgets.get("catalog_name")
schema_name  = dbutils.widgets.get("schema_name")

silver = spark.table(f"{catalog_name}.{schema_name}.silver_openaq_clean")

gold_df = (
    silver
    # ── Aggregate to daily summary per location + pollutant ────────
    .groupBy(
        "location_id",
        "location_name",
        "pollutant",
        "unit",
        "latitude",
        "longitude",
        "measured_date",
        "measured_year",
        "measured_month"
    )
    .agg(
        F.round(F.avg("value"),    4).alias("daily_avg"),
        F.round(F.max("value"),    4).alias("daily_max"),
        F.round(F.min("value"),    4).alias("daily_min"),
        F.round(F.stddev("value"), 4).alias("daily_stddev"),
        F.count("value")             .alias("reading_count")
    )
    # ── EPA AQI category for PM2.5 only ───────────────────────────
    .withColumn("pm25_aqi_category",
        F.when(F.col("pollutant") != "pm25", F.lit(None))
         .when(F.col("daily_avg") <= 12.0,  F.lit("Good"))
         .when(F.col("daily_avg") <= 35.4,  F.lit("Moderate"))
         .when(F.col("daily_avg") <= 55.4,  F.lit("Unhealthy for Sensitive Groups"))
         .when(F.col("daily_avg") <= 150.4, F.lit("Unhealthy"))
         .otherwise(F.lit("Very Unhealthy"))
    )
    # ── Relative Humidity Index ───────────────────────────────────
    .withColumn("rel_humidity_index",
        F.when(F.col("pollutant") != "relativehumidity", F.lit(None))
         .when(F.col("daily_max") <  60.0, F.lit("Low"))
         .when(F.col("daily_max") <= 70.0, F.lit("Medium"))
         .when(F.col("daily_max") <= 75.0, F.lit("High"))
         .otherwise(F.lit("Very High"))
    )
)

(
    gold_df.write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .partitionBy("measured_year", "measured_month")
    .saveAsTable(f"{catalog_name}.{schema_name}.gold_openaq_daily")
)
