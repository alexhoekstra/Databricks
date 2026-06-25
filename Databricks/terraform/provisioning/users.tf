#users.tf

resource "databricks_user" "someone_admin" {
  user_name = "someone1@example.com"
  display_name = "Someone Admin"
}

resource "databricks_user" "someone" {
  user_name = "someone2@example.com"
  display_name = "Someone"
}

# add someone_admin user to the example admin group
resource "databricks_group_member" "someone_admin_group_memeber" {
  group_id  = databricks_group.example_admin_group.id
  member_id = databricks_user.someone_admin.id
}

# add someone_admin user to the example admin group
resource "databricks_group_member" "someone_group_member" {
  group_id  = databricks_group.example_user_group.id
  member_id = databricks_user.someone.id
}