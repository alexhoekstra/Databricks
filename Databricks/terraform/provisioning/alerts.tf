### alerts.tf
resource "databricks_notification_destination" "administrator_alert_destination" {
  display_name = "Databricks Administrator Alert Destination"
  config {
    email {
      addresses = [module.vault_secrets.secrets["my_email"]]
    }
  }
}