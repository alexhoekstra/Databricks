# ==============================================================================
# outputs.tf
# ==============================================================================

output "groups" {
  description = "Team name -> workspace group id."
  value       = { for key, group in databricks_group.team : key => group.id }
}

output "schemas" {
  description = "Schema key -> full catalog.schema name."
  value       = { for key, schema in databricks_schema.managed : key => schema.id }
}

output "service_principal_application_ids" {
  description = "Service principal key -> application (client) id."
  value       = { for key, sp in databricks_service_principal.automation : key => sp.application_id }
}

output "catalog_grants" {
  description = "Derived USE_CATALOG grants."
  value = sort([
    for key, grant in local.user_catalog_grants : "${grant.email} -> ${grant.catalog}"
  ])
}

output "schema_grant_pairs" {
  description = "Every (user, schema) grant with unioned privileges."
  value = {
    for key, grant in local.user_schema_grants :
    "${grant.email} ${grant.schema_key}" => sort(grant.privileges)
  }
}

output "members" {
  description = "Team -> sorted member emails."
  value       = { for team, emails in local.team_emails : team => sort(emails) }
}
