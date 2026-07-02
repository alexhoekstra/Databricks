# ==============================================================================
# main.tf  (data_quality checks root)   [SCAFFOLD — TODO implement]
# Provisions the DQ results schema/table, a SINGLE layer-aware check job (per-
# table tasks, <=5 concurrent), SQL alerts, and an AI/BI dashboard.
#
# Points at tables produced by ../../declarative_bronze (or any UC table) via
# var.monitored_tables.
#
# NOTE: declarative_bronze now DISCOVERS its bronze tables at pipeline runtime, so
# there is no static table list to import. Rather than hand-maintaining
# var.monitored_tables, enumerate the bronze tables from Unity Catalog — e.g. a
# `data "databricks_tables"` on main.declarative_bronze filtered to "*_bronze", or
# an information_schema.tables query via the warehouse — and build the monitored set
# from that. See the stub below.
# ==============================================================================

terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "databricks" {}

# TODO: discover bronze tables from UC instead of requiring var.monitored_tables.
#   data "databricks_tables" "bronze" {
#     catalog_name = "main"
#     schema_name  = "declarative_bronze"
#   }
#   locals {
#     discovered_bronze = {
#       for id in data.databricks_tables.bronze.ids : id => { table = id, layer = "bronze" }
#       if endswith(id, "_bronze")
#     }
#   }
# Then for_each the check job over coalesce-merged discovered + var.monitored_tables.

# TODO: dq schema + results Delta table (history, tagged by layer).
# resource "databricks_schema" "dq" { ... }

# TODO: ONE job; tasks for_each over var.monitored_tables (cap concurrency <= 5).
#   Each task runs bundle/src/run_checks.py with { table, layer, ... }.
# resource "databricks_job" "checks" {
#   dynamic "task" {
#     for_each = var.monitored_tables
#     content { ... python params: table, layer, primary_keys, checks ... }
#   }
#   max_concurrent_runs = 1
# }

# TODO: databricks_alert_v2 on breach conditions (freshness/volume/quality).
# TODO: databricks_dashboard with bronze + silver tabs (2X-Small warehouse).
