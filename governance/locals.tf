# ==============================================================================
# locals.tf
# ==============================================================================

# Grants are derived per-user (emails): this workspace only resolves
# account-level principals, so groups can't be grant targets (see README).

locals {
  # Access matrix is committed JSON so access changes are reviewable PRs.
  teams = jsondecode(file("${path.module}/access_matrix.json")).teams

  # (catalog, schema) pairs keyed "catalog/schema"
  schema_defs = {
    for pair in flatten([
      for catalog_key, catalog in var.catalogs : [
        for schema_key, schema in catalog.schemas : {
          key     = "${catalog_key}/${schema_key}"
          catalog = catalog_key
          schema  = schema_key
          comment = schema.comment
        }
      ]
    ]) : pair.key => pair
  }

  # membership CSVs, one per team (header: name,email)
  team_rows = {
    for team_key in keys(local.teams) :
    team_key => csvdecode(file("${path.module}/members/${team_key}.csv"))
  }

  team_emails = {
    for team_key, rows in local.team_rows :
    team_key => distinct([for row in rows : lower(trimspace(row.email))])
  }

  all_rows = flatten([
    for team_key, rows in local.team_rows : [
      for row in rows : {
        team  = team_key
        name  = trimspace(row.name)
        email = lower(trimspace(row.email))
      }
    ]
  ])

  # users deduped across teams by lowercased email
  users = {
    for email, names in { for row in local.all_rows : row.email => row.name... } :
    email => names[0]
  }

  team_members = {
    for record in distinct([
      for row in local.all_rows : { team = row.team, email = row.email }
    ]) : "${record.team}/${record.email}" => record
  }

  # (member x team schema grant) triples, regrouped so a user on several teams
  # gets the union of their privileges on a shared schema
  user_grant_triples = flatten([
    for team_key, team in local.teams : [
      for email in local.team_emails[team_key] : [
        for schema_key, privileges in team.schema_grants : [
          for privilege in privileges : {
            key        = "${email}|${schema_key}"
            email      = email
            schema_key = schema_key
            privilege  = privilege
          }
        ]
      ]
    ]
  ])

  user_schema_grants = {
    for key, triples in { for t in local.user_grant_triples : t.key => t... } :
    key => {
      email      = triples[0].email
      schema_key = triples[0].schema_key
      privileges = distinct([for t in triples : t.privilege])
    }
  }

  # one USE_CATALOG per (user, catalog) appearing in their schema grants
  user_catalog_grants = {
    for pair in distinct([
      for grant in values(local.user_schema_grants) : {
        email   = grant.email
        catalog = split("/", grant.schema_key)[0]
      }
    ]) : "${pair.email}|${pair.catalog}" => pair
  }

  sp_members = {
    for pair in flatten([
      for sp_key, sp in var.service_principals : [
        for team_key in sp.teams : {
          key  = "${sp_key}/${team_key}"
          sp   = sp_key
          team = team_key
        }
      ]
    ]) : pair.key => pair
  }
}
