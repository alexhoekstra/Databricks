# terraform.tfvars — committed: the CI apply job reads this. No secrets here; auth comes from env vars.
# Teams/grants live in access_matrix.json; membership in members/<team>.csv.
catalogs = {
  hr = {
    schemas = {
      bronze = { comment = "HR raw ingest (personnel feed) — platform engineers only." }
      silver = { comment = "HR curated employees — PII column-masked for non-pii_readers." }
      gold   = { comment = "HR aggregates — headcount by program (no row-level PII)." }
    }
  }

  finance = {
    schemas = {
      bronze = { comment = "Finance raw ingest (contract lines) — platform engineers only." }
      silver = { comment = "Finance curated contracts — vendor, appropriation, fiscal year." }
      gold   = { comment = "Finance aggregates — program spend rollups (dollar totals)." }
    }
  }

  programs = {
    schemas = {
      bronze = { comment = "Programs raw ingest (milestones feed) — platform engineers only." }
      silver = { comment = "Programs curated — ITAR-restricted rows filtered for non-export_cleared." }
      gold   = { comment = "Programs aggregates — non-ITAR program status rollup." }
    }
  }
}

service_principals = {
  # governance_ci = { teams = ["platform_engineers"] }
}
