# wc_bundle_etl

Lakeflow pipeline source for World Cup team stats.

- `transformations/silver_wc_teams.py` — reads `main.wc.wc_teams_bronze`, writes `wc_teams_silver`
- `transformations/gold_wc_teams.py` — writes `wc_teams_gold_rankings` and `wc_teams_gold_country_summary`

Bronze ingestion is handled outside this bundle by the scalable ingestion pipeline.

This bundle includes a (serverless) table trigger job that triggers off of `main.wc.wc_teams_bronze` updates
