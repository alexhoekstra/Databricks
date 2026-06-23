"""Create the silver weather table with cleaned types and date fields.
   Note: this was mostly AI generated so I could focus on testing the pipeline and github action,
   and not the data cleaning. """
from databricks.sdk.runtime import spark
from pyspark import pipelines as dp
from pyspark.sql import functions as F
from functools import reduce


def _normalize_name(name: str) -> str:
    return "".join(ch for ch in name.lower() if ch.isalnum())


def _first_existing_column(df, candidates):
    lookup = { _normalize_name(column): column for column in df.columns }
    for candidate in candidates:
        normalized = _normalize_name(candidate)
        if normalized in lookup:
            return lookup[normalized]
    return None


def _find_date_column(df):
    for column in df.columns:
        if column.startswith("_"):
            continue

        normalized = _normalize_name(column)
        if normalized in {"ingestiondate", "ingestedat", "updatedat", "lastupdatedepoch", "localtimeepoch"}:
            continue

        if (
            normalized == "date"
            or normalized.endswith("date")
            or normalized.endswith("datetime")
            or normalized.endswith("timestamp")
            or normalized.endswith("time")
        ):
            return column
    return None


def _to_timestamp_expression(column_name: str):
    normalized = _normalize_name(column_name)
    if normalized.endswith("epoch"):
        return F.to_timestamp(F.from_unixtime(F.col(column_name)))
    return F.to_timestamp(F.col(column_name))


def _cast_columns(df, columns):
    for column in columns:
        if column in df.columns:
            df = df.withColumn(column, F.col(column).cast("double"))
    return df


def _combine_columns(columns):
    return reduce(lambda a, b: a | b, columns)


@dp.table
def silver_daily_capitals_weather():
    """Create the silver weather table with cleaned types and date fields."""
    bronze_df = spark.read.table("bronze_daily_capitals_weather")

    rename_map = {
        "station": ["station", "station_name", "weather_station"],
        "city": ["city", "town", "location", "location_name"],
        "country": ["country", "nation", "country_name"],
        "latitude": ["latitude", "lat"],
        "longitude": ["longitude", "lon", "lng"],
        "observation_date": ["observation_date", "date", "observationdate", "measurementdate"],
        "observation_timestamp": ["observation_timestamp", "datetime", "timestamp", "time", "observationtimestamp", "last_updated", "lastupdated", "last_updated_epoch", "lastupdatedepoch", "localtime", "localtime_epoch", "localtimeepoch"],
        "mean_temperature": ["mean_temperature", "mean_temp", "avg_temperature", "average_temperature", "meantemp", "temperature", "temp"],
        "max_temperature": ["max_temperature", "max_temp", "highest_temperature", "maxtemp"],
        "min_temperature": ["min_temperature", "min_temp", "lowest_temperature", "mintemp"],
        "precipitation": ["precipitation", "rain_mm", "rainfall", "precip", "rain"],
        "humidity": ["humidity", "relative_humidity", "rh"],
        "wind_speed": ["wind_speed", "wind_mph", "wind_kph", "wind", "windspeed"],
    }

    selected = []
    timestamp_source = _first_existing_column(bronze_df, rename_map["observation_timestamp"])
    for target, candidates in rename_map.items():
        if target == "observation_timestamp":
            continue

        source_column = _first_existing_column(bronze_df, candidates)
        if source_column:
            selected.append(F.col(source_column).alias(target))

    if timestamp_source:
        selected.append(_to_timestamp_expression(timestamp_source).alias("observation_timestamp"))

    silver_df = bronze_df.select(*selected)

    silver_df = _cast_columns(
        silver_df,
        [
            "mean_temperature",
            "max_temperature",
            "min_temperature",
            "precipitation",
            "humidity",
            "wind_speed",
        ],
    )

    if "observation_date" not in silver_df.columns:
        date_col = _find_date_column(bronze_df)
        if date_col:
            silver_df = silver_df.withColumn("observation_date", F.to_date(F.col(date_col)))

    if "observation_timestamp" not in silver_df.columns and "observation_date" not in silver_df.columns:
        timestamp_col = _first_existing_column(bronze_df, ["datetime", "timestamp", "time"])
        if timestamp_col:
            silver_df = silver_df.withColumn("observation_timestamp", F.to_timestamp(F.col(timestamp_col)))

    if "observation_timestamp" in silver_df.columns and "observation_date" not in silver_df.columns:
        silver_df = silver_df.withColumn("observation_date", F.to_date("observation_timestamp"))

    if "observation_date" not in silver_df.columns and "_ingestion_date" in bronze_df.columns:
        silver_df = silver_df.withColumn("observation_date", F.to_date(F.col("_ingestion_date")))

    if "observation_date" in silver_df.columns:
        silver_df = silver_df.withColumn("year", F.year("observation_date"))
        silver_df = silver_df.withColumn("month", F.month("observation_date"))
        silver_df = silver_df.withColumn("day", F.dayofmonth("observation_date"))

    if "observation_date" in silver_df.columns:
        location_columns = [
            F.col(col_name).isNotNull()
            for col_name in ["country", "city", "station"]
            if col_name in silver_df.columns
        ]
        if location_columns:
            silver_df = silver_df.filter(F.col("observation_date").isNotNull() & _combine_columns(location_columns))
        else:
            silver_df = silver_df.filter(F.col("observation_date").isNotNull())

    return silver_df
