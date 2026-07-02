# ==============================================================================
# variables.tf  (data_quality checks root)   [SCAFFOLD — TODO refine]
# ==============================================================================

variable "monitored_tables" {
  description = <<-EOT
    Map of logical name -> table to monitor. The `layer` discriminator selects
    the default metric set: bronze => operational/observability metrics,
    silver => content-quality/conformance metrics.

    OPTIONAL once UC discovery (see main.tf TODO) is wired up: declarative_bronze
    tables are discovered from Unity Catalog (main.declarative_bronze *_bronze), so
    this map is for extra/silver tables or per-table overrides, not the full list.
  EOT

  type = map(object({
    table = string # fully-qualified: catalog.schema.table
    layer = string # "bronze" | "silver"

    # Bronze-oriented:
    freshness_sla    = optional(string) # e.g. "24h" — max(_ingest_ts) staleness
    volume_tolerance = optional(number) # allowed deviation vs rolling baseline

    # Silver-oriented:
    primary_keys = optional(list(string), []) # for uniqueness / SCD checks

    # Extra ad-hoc checks: name -> SQL boolean expression that must hold.
    checks = optional(map(string), {})
  }))
}

variable "warehouse_id" {
  description = "Serverless SQL warehouse (the single 2X-Small on Free Edition) for alerts/dashboard."
  type        = string
}
