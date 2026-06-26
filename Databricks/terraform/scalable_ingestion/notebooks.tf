# Place the notebooks on the shared drive
resource "databricks_notebook" "generic_extractor" {
  source = "${path.module}/../../notebooks/scalable_ingestion/generic_extractor.py"
  path = "/Shared/scalable_ingestion/generic_extractor"
  language = "PYTHON"
}

resource "databricks_notebook" "generic_autoloader" {
  source = "${path.module}/../../notebooks/scalable_ingestion/generic_autoloader.py"
  path = "/Shared/scalable_ingestion/generic_autoloader"
  language = "PYTHON"
}
