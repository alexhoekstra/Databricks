"""This module contains the logic to download the latest version of the weather dataset 
and load it into a Spark DataFrame."""
import kagglehub
from kagglehub import KaggleDatasetAdapter
from pyspark.sql import DataFrame
from pyspark.sql import functions as F
from databricks.sdk.runtime import spark


def get_weather_data() -> DataFrame:
    """Downloads the latest version of the dataset and loads it into a Spark DataFrame."""

    # Download latest version of the dataset
    # and load the weather data into a Pandas DataFrame
    df_pandas = kagglehub.load_dataset(
        KaggleDatasetAdapter.PANDAS,
        "nelgiriyewithana/global-weather-repository",
        "GlobalWeatherRepository.csv",
    )

    # Convert the Pandas DataFrame to a Spark DataFrame
    df_raw = spark.createDataFrame(df_pandas)

    # create bronze dataframe by adding ingestion metadata
    df_bronze = (
        df_raw
        .withColumn("_ingested_at",    F.current_timestamp())
        .withColumn("_ingestion_date", F.to_date(F.current_timestamp()))
    )
    return df_bronze
