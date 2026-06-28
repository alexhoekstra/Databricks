# Declarable Automation Bundles - Databricks

This folder contains the repository's Declarable Automation Bundles

## Contents

### `daily_capitals_weather`
This DAB handles daily ingestion and processing of weather data pulled from the [World Weather Repository (Daily Updating)](https://www.kaggle.com/datasets/nelgiriyewithana/global-weather-repository) kaggle dataset.

### `wc_bundle`
This DAB consists of a data pipeline, holding Silver and Gold tables. The pipeline is updated on a trigger that fires when the bronze table created in [`scalable_ingestion`](/scalable_ingestion) is updated.