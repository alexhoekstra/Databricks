""" Create the gold weather summary with aggregated daily metrics.
    Note: this was mostly AI generated so I could focus on testing the pipeline and github action,
    and not the data cleaning. """
from databricks.sdk.runtime import spark
from pyspark import pipelines as dp
from pyspark.sql import functions as F


@dp.table
def gold_daily_capitals_weather():
    """Build the gold weather summary with aggregated daily metrics."""
    silver_df = spark.read.table("silver_daily_capitals_weather")

    if "observation_date" not in silver_df.columns and "observation_timestamp" in silver_df.columns:
        silver_df = silver_df.withColumn("observation_date", F.to_date("observation_timestamp"))

    group_by_columns = [
        c
        for c in ["country", "city", "station", "observation_date"]
        if c in silver_df.columns
    ]

    if "observation_date" not in group_by_columns:
        raise ValueError("silver_daily_capitals_weather must contain observation_date for gold aggregation")

    agg_expressions = [F.count("*").alias("observation_count")]

    if "mean_temperature" in silver_df.columns:
        agg_expressions.append(F.avg("mean_temperature").alias("avg_mean_temperature"))

    if "max_temperature" in silver_df.columns:
        agg_expressions.append(F.max("max_temperature").alias("max_temperature"))

    if "min_temperature" in silver_df.columns:
        agg_expressions.append(F.min("min_temperature").alias("min_temperature"))

    if "precipitation" in silver_df.columns:
        agg_expressions.append(F.sum("precipitation").alias("total_precipitation"))

    if "humidity" in silver_df.columns:
        agg_expressions.append(F.avg("humidity").alias("avg_humidity"))

    if "wind_speed" in silver_df.columns:
        agg_expressions.append(F.avg("wind_speed").alias("avg_wind_speed"))

    return silver_df.groupBy(*group_by_columns).agg(*agg_expressions)
