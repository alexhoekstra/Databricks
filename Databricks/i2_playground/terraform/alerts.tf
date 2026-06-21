# Query for testing the alert
resource "databricks_query" "test_query" {
  warehouse_id = data.databricks_sql_warehouse.default.id
  display_name = "Test Query"
  query_text   = "SELECT 42 as value"
  parent_path  = databricks_directory.shared_dir.path
}

#test alert
resource "databricks_alert" "alert" {
  query_id     = databricks_query.test_query.id
  display_name = "Test Query Threshold alert"
  parent_path  = databricks_directory.shared_dir.path
  condition {
    op = "GREATER_THAN"
    operand {
      column {
        name = "value"
      }
    }
    threshold {
      value {
        double_value = 42
      }
    }
  }
}