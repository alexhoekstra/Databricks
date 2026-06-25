resource "databricks_notebook" "bronze_openaq" {
  path = "/Shared/openaq/aq_bronze_autoloader"
  source = "${path.module}/../../notebooks/aq/aq_bronze_autoloader.py"
  depends_on = [databricks_schema.openaq]
}

resource "databricks_notebook" "silver_openaq" {
  path = "/Shared/openaq/aq_silver_clean"
  source = "${path.module}/../../notebooks/aq/aq_silver_clean.py"
  depends_on = [databricks_schema.openaq]
}

resource "databricks_notebook" "gold_openaq" {
  path = "/Shared/openaq/aq_gold_daily_summary"
  source = "${path.module}/../../notebooks/aq/aq_gold_daily_summary.py"
  depends_on = [databricks_schema.openaq]
}

resource "databricks_notebook" "worldcup_bronze_ingest" {
  source = "${path.module}/../../notebooks/world_cup/world_cup.ipynb"
  path = "/Shared/openaq/worldcup_bronze_ingest"
  depends_on = [databricks_schema.worldcup]
}