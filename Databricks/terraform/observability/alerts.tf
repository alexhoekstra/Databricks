### alerts.tf
resource "databricks_notification_destination" "email_alerts" {
  display_name = "Databricks Notification Alert"
  config {
    email {
      addresses = ["data-ops-team@company.com"]
    }
  }
}