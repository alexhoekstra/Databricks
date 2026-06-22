from pyspark import pipelines as dp

from daily_capitals_weather.weather import get_weather_data


@dp.table
def bronze_weather_daily_capitals_weather():
    """Return the bronze weather DataFrame with ingestion metadata."""
    return get_weather_data()
