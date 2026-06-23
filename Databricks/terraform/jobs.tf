resource "databricks_job" "openaq_pipeline" {
    name = "openaq-medallion-pipeline"

    schedule {
        quartz_cron_expression = "0 0 11 * * ?"  # daily at 7 AM ET (11:00 UTC)
        timezone_id            = "America/New_York"
        pause_status           = "UNPAUSED"
    }

    environment {
        environment_key = "default"
        spec {
            client       = "2" 
            dependencies = []
        }
    }

    task {
        task_key        = "bronze_ingest"
        environment_key = "default"

        notebook_task {
            notebook_path = databricks_notebook.bronze_openaq.path
            base_parameters = {
                location_ids = join(",", [for id in var.openaq_location_ids : tostring(id)])
                start_year   = "2025"
                catalog_name = var.catalog_name
                schema_name  = var.aq_schema_name
                checkpoint_base = "/Volumes/${var.catalog_name}/${var.aq_schema_name}/checkpoints"
            }
        }
    }
    # Gold needed to come first before silver because terraform still cares about block ordering, even if the depends on key preserves execution order
    # By ordering it this way, it will still execute, but stop continually "modifying" the resource
    task {
        task_key        = "gold_summary"
        environment_key = "default"
        depends_on { task_key = "silver_clean" }

        notebook_task {
            notebook_path = databricks_notebook.gold_openaq.path
            base_parameters = {
            catalog_name = var.catalog_name
            schema_name  = var.aq_schema_name
            }
        }
    }

    task {
        task_key        = "silver_clean"
        environment_key = "default"
        depends_on { task_key = "bronze_ingest" }

        notebook_task {
            notebook_path = databricks_notebook.silver_openaq.path
            base_parameters = {
            catalog_name        = var.catalog_name
            schema_name         = var.aq_schema_name
            openaq_location_ids = join(",", [for id in var.openaq_location_ids : tostring(id)])
            }
        }
    }
}

resource "databricks_job" "fifa_ingestion" {
    name = "fifa-wc-2026-ingest"

    schedule {
        quartz_cron_expression = "0 0 14 * * ?"
        timezone_id            = "America/New_York"
        pause_status           = "UNPAUSED"
    }

    environment {
        environment_key = "default"
        spec {
            client       = "2" 
            dependencies = ["kagglehub"]
        }
    }

    task {
        task_key = "bronze_ingest"
        environment_key = "default"

        notebook_task {
            notebook_path = databricks_notebook.worldcup_bronze_ingest.path
            # Pass config into the notebook as widgets
            base_parameters = {
                catalog_name = var.catalog_name
                schema_name  = var.worldcup_schema_name
                table   = "bronze_raw_fifa_wc_2026_teams"
            }
        }
    }
}
