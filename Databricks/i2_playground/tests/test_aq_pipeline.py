""" Unit tests for AQ pipeline transformations."""

import pytest
from pyspark.sql import SparkSession
from pyspark.sql import functions as F


@pytest.fixture(scope="session")
def spark_session_fixture():
    """Create a SparkSession for testing."""
    return (
        SparkSession.builder.master("local[2]")
        .appName("aq_pipeline_tests")
        .getOrCreate()
    )


def test_silver_clean_transforms(spark_session_fixture): # pylint: disable=redefined-outer-name
    """Sample raw (bronze) input matching columns used in 
    notebook and validate silver transformations."""
    raw = [
        (100, 100, "2024-01-01 01:00:00", "10.5", "pm25", "ug/m3", "Loc A", 1.0, 2.0),
        (100, 100, "2024-01-01 01:00:00", "10.5", "pm25", "ug/m3", "Loc A", 1.0, 2.0),  # duplicate
        (100, 100, "2024-01-02 02:00:00", None, "pm25", "ug/m3", "Loc A", 1.0, 2.0),    # null value
        (200, 200, "2024-01-03 03:00:00", "-5.0", "pm25", "ug/m3", "Loc B", 3.0, 4.0),  # negative
        (300, 300, "2024-01-04 04:00:00", "2.25", "relativehumidity", "%", "Loc C", 5.0, 6.0),
    ]

    cols = [
        "location_id",
        "locationid",
        "datetime",
        "value",
        "parameter",
        "units",
        "location",
        "lat",
        "lon",
    ]

    df = spark_session_fixture.createDataFrame(raw, schema=cols)

    # apply same transformations as aq_silver_clean.py
    location_ids = [100, 300]

    silver_df = (
        df
        .filter(F.col("location_id").isin(location_ids))
        .drop("locationid")
        .withColumn("measured_at", F.to_timestamp("datetime"))
        .withColumn("measured_date", F.to_date("measured_at"))
        .withColumn("measured_year", F.year("measured_at"))
        .withColumn("measured_month", F.month("measured_at"))
        .withColumn("value", F.col("value").cast("double"))
        .filter(F.col("value").isNotNull())
        .filter(F.col("value") >= 0)
        .withColumnRenamed("parameter", "pollutant")
        .withColumnRenamed("units", "unit")
        .withColumnRenamed("location", "location_name")
        .withColumnRenamed("lat", "latitude")
        .withColumnRenamed("lon", "longitude")
        .drop("datetime")
        .dropDuplicates(["location_id", "pollutant", "measured_at"])
    )

    res = silver_df.collect()

    # Expect two rows: one for location_id 100 (duplicate removed) and one for 300
    assert len(res) == 2

    cols_out = set(silver_df.columns)
    expected_cols = set([
        "location_id",
        "value",
        "pollutant",
        "unit",
        "location_name",
        "latitude",
        "longitude",
        "measured_at",
        "measured_date",
        "measured_year",
        "measured_month",
    ])
    assert expected_cols.issubset(cols_out)


def test_gold_daily_summary_aggregations(spark_session_fixture): # pylint: disable=redefined-outer-name
    """Create sample silver input and validate gold 
    daily summary aggregations and derived columns."""
    rows = [
        (100, "Loc A", "pm25", "ug/m3", 1.0, 2.0,
         "2024-01-01 01:00:00", "2024-01-01", 2024, 1, 10.0),
        (100, "Loc A", "pm25", "ug/m3", 1.0, 2.0,
         "2024-01-01 05:00:00", "2024-01-01", 2024, 1, 20.0),
        (100, "Loc A", "relativehumidity", "%", 1.0, 2.0,
         "2024-01-01 06:00:00", "2024-01-01", 2024, 1, 65.0),
        (200, "Loc B", "pm25", "ug/m3", 3.0, 4.0,
         "2024-01-02 02:00:00", "2024-01-02", 2024, 1, 40.0),
    ]

    cols = [
        "location_id",
        "location_name",
        "pollutant",
        "unit",
        "latitude",
        "longitude",
        "measured_at",
        "measured_date",
        "measured_year",
        "measured_month",
        "value",
    ]

    silver = spark_session_fixture.createDataFrame(rows, schema=cols)

    gold_df = (
        silver
        .groupBy(
            "location_id",
            "location_name",
            "pollutant",
            "unit",
            "latitude",
            "longitude",
            "measured_date",
            "measured_year",
            "measured_month",
        )
        .agg(
            F.round(F.avg("value"), 4).alias("daily_avg"),
            F.round(F.max("value"), 4).alias("daily_max"),
            F.round(F.min("value"), 4).alias("daily_min"),
            F.round(F.stddev("value"), 4).alias("daily_stddev"),
            F.count("value").alias("reading_count"),
        )
        .withColumn(
            "pm25_aqi_category",
            F.when(F.col("pollutant") != "pm25", F.lit(None))
            .when(F.col("daily_avg") <= 12.0, F.lit("Good"))
            .when(F.col("daily_avg") <= 35.4, F.lit("Moderate"))
            .when(F.col("daily_avg") <= 55.4, F.lit("Unhealthy for Sensitive Groups"))
            .when(F.col("daily_avg") <= 150.4, F.lit("Unhealthy"))
            .otherwise(F.lit("Very Unhealthy")),
        )
        .withColumn(
            "rel_humidity_index",
            F.when(F.col("pollutant") != "relativehumidity", F.lit(None))
            .when(F.col("daily_max") < 60.0, F.lit("Low"))
            .when(F.col("daily_max") <= 70.0, F.lit("Medium"))
            .when(F.col("daily_max") <= 75.0, F.lit("High"))
            .otherwise(F.lit("Very High")),
        )
    )

    collected = { (r.location_id, r.pollutant, r.measured_date): r for r in gold_df.collect() }

    # Check pm25 category for location 100 average (10 and 20 -> avg 15 -> Moderate)
    key_pm25 = (100, "pm25", "2024-01-01")
    assert key_pm25 in collected
    row_pm25 = collected[key_pm25]
    assert row_pm25.daily_avg == pytest.approx(15.0, rel=1e-3)
    assert row_pm25.pm25_aqi_category == "Moderate"

    # Check relative humidity index for location 100 (daily_max 65 -> Medium)
    key_rh = (100, "relativehumidity", "2024-01-01")
    assert key_rh in collected
    row_rh = collected[key_rh]
    assert row_rh.rel_humidity_index == "Medium"
