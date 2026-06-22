""" test file for weather module """
from daily_capitals_weather.weather import get_weather_data

def test_get_weather_data():
    """Test that the get_weather_data function returns a DataFrame with more than 5 rows."""
    results = get_weather_data()
    assert results.count() > 5
