resource "databricks_notebook" "bronze_openaq" {
  path     = "/Shared/openaq/aq_bronze_autoloader"
  language = "PYTHON"
  content_base64 = filebase64("${path.module}/../notebooks/aq/aq_bronze_autoloader.py")
  depends_on = [databricks_schema.openaq]
}

resource "databricks_notebook" "silver_openaq" {
  path     = "/Shared/openaq/aq_silver_clean"
  language = "PYTHON"
  content_base64 = filebase64("${path.module}/../notebooks/aq/aq_silver_clean.py")
  depends_on = [databricks_schema.openaq]
}

resource "databricks_notebook" "gold_openaq" {
  path     = "/Shared/openaq/aq_gold_daily_summary"
  language = "PYTHON"
  content_base64 = filebase64("${path.module}/../notebooks/aq/aq_gold_daily_summary.py")
  depends_on = [databricks_schema.openaq]
}