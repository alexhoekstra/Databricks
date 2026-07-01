# World Cup Bundle

Databricks Asset Bundle for World Cup team statistics. Transforms the existing
`main.wc.wc_teams_bronze` table through silver cleaning and gold analytics layers.

This bundle has a job that will trigger the pipeline run when the `main.wc.wc_teams_bronze` table that was created through the [:star:`scalable_ingestion`](/explorations/terraform/scalable_ingestion/) is updated.

The [`deploy_dab_bundles.yml`](/.github/workflows/deploy_dab_bundles.yml) Github Action will also automatically deploy this bundle using a Service Principal account.


## Source

| Layer  | Table                           | Description                                      |
|-------|----------------------------------|--------------------------------------------------|
| Bronze | `main.wc.wc_teams_bronze`       | Existing managed table (ingested separately)     |
| Silver | `wc_teams_silver`               | Cleaned types, derived metrics, null filtering   |
| Gold   | `wc_teams_gold_rankings`        | Team rankings and offensive tier classification  |
| Gold   | `wc_teams_gold_country_summary` | Country-level performance rollups                |

## Deploy

```bash
cd explorations/bundles/wc_bundle
databricks bundle deploy --target dev    # isolated dev schema
databricks bundle deploy --target prod   # writes to main.wc
```

## Run pipeline

```bash
databricks bundle run wc_teams_etl --target dev
```

## Layout

- `resources/` — pipeline definition
- `src/wc_bundle_etl/transformations/` — silver and gold transformation modules
