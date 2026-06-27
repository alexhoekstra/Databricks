#groups.tf

resource "databricks_group" "example_admin_group" {
  display_name               = "Example Workspace Admin Group"
  allow_cluster_create       = true
  allow_instance_pool_create = true
}

resource "databricks_group" "example_user_group" {
  display_name               = "Example Workspace User Group"
  allow_cluster_create       = false
  allow_instance_pool_create = false
}