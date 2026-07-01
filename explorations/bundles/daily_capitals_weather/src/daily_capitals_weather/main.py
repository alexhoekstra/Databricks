""" This is the main entry point for the wheel file. It contains a main() function that will be
executed when the wheel is run as a script. The main() function processes command-line arguments 
for catalog and schema, sets the Spark session to use the specified catalog and schema, and then 
calls the get_weather_data() function from the weather module to"""
import argparse
from databricks.sdk.runtime import spark
from daily_capitals_weather import weather



def main():
    """ Main function """
    # Process command-line arguments
    parser = argparse.ArgumentParser(
        description="Databricks job with catalog and schema parameters",
    )
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--schema", required=True)

    args = parser.parse_args()

    # Set the default catalog and schema
    spark.sql(f"USE CATALOG {args.catalog}")
    spark.sql(f"USE SCHEMA {args.schema}")

    weather.get_weather_data().show(5)


if __name__ == "__main__":
    main()
