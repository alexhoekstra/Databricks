# ==============================================================================
# identities.tf
# ==============================================================================

resource "databricks_group" "team" {
  for_each     = local.teams
  display_name = each.key
}

# destroy deletes these users — demo/alias emails only (see README)
resource "databricks_user" "member" {
  for_each     = local.users
  user_name    = each.key
  display_name = each.value
}

resource "databricks_group_member" "user" {
  for_each  = local.team_members
  group_id  = databricks_group.team[each.value.team].id
  member_id = databricks_user.member[each.value.email].id
}

resource "databricks_service_principal" "automation" {
  for_each     = var.service_principals
  display_name = each.key
}

resource "databricks_group_member" "service_principal" {
  for_each  = local.sp_members
  group_id  = databricks_group.team[each.value.team].id
  member_id = databricks_service_principal.automation[each.value.sp].id
}
