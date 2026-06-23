from pyspark import pipelines as dp
from pyspark.sql import functions as F
from daily_capitals_weather.weather import get_weather_data


@dp.table
def bronze_daily_capitals_weather():
    """Return the bronze weather DataFrame with ingestion metadata."""
    df_raw = get_weather_data()

    df_bronze = (
        df_raw
        .withColumn("_ingested_at", F.current_timestamp())
        .withColumn("_ingestion_date", F.to_date(F.current_timestamp()))
    )

    return df_bronze
