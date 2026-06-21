resource "databricks_job" "openaq_pipeline" {
    name = "openaq-medallion-pipeline"

    schedule {
        quartz_cron_expression = "0 0 11 * * ?"  # daily at 7 AM ET (11:00 UTC)
        timezone_id            = "America/New_York"
        pause_status           = "UNPAUSED"
    }

    environment {
        environment_key = "default"      # this key is what tasks reference
        spec {
            client       = "2" # 2 allows for notebooks
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
                start_year   = "2023"
                catalog_name = var.catalog_name
                schema_name  = var.schema_name
                checkpoint_base = "/Volumes/${var.catalog_name}/${var.schema_name}/checkpoints"
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
            schema_name         = var.schema_name
            openaq_location_ids = join(",", [for id in var.openaq_location_ids : tostring(id)])
            }
        }
    }

    task {
        task_key        = "gold_summary"
        environment_key = "default"
        depends_on { task_key = "silver_clean" }

        notebook_task {
            notebook_path = databricks_notebook.gold_openaq.path
            base_parameters = {
            catalog_name = var.catalog_name
            schema_name  = var.schema_name
            }
        }
    }
}