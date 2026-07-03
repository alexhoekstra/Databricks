# ==============================================================================
# guard.tf
# ==============================================================================

# Fails plan when a schema_grants key in access_matrix.json doesn't name a
# declared catalog/schema.
resource "terraform_data" "access_matrix_guard" {
  input = keys(local.schema_defs)

  lifecycle {
    precondition {
      condition = length(setsubtract(
        flatten([for team in local.teams : keys(team.schema_grants)]),
        keys(local.schema_defs)
      )) == 0
      error_message = "Every schema_grants key in access_matrix.json must be \"catalog/schema\" naming a declared pair (e.g. \"hr/silver\")."
    }
  }
}
