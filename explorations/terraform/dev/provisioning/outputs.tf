output "administrator_alert_destination_id" {
  value       = databricks_notification_destination.administrator_alert_destination.id
  description = "ID of the administrator_alert_destination"
}

output "example_user_group_name" {
  value       = databricks_group.example_user_group.display_name
  description = "name of the example user group"
}
