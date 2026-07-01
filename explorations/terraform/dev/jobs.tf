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
        pause_status           = "PAUSED"
    }

    # Define the SLA window
    health {
        rules {
            metric = "RUN_DURATION_SECONDS"
            op     = "GREATER_THAN"
            value  = 1800 # 30 minutes in seconds
        }
    }

    #NOTE:  I tried using data.terraform_remote_state.provisioning.outputs.administrator_alert_destination_id instead of the email as string here
    #       however I discovered that databricks_notification_destination is essentially a workspace-level named alert channel designed for the 
    #       Databricks UI and monitoring features such as budget alerts and quality monitors— not for job notifications.
    email_notifications {
        on_duration_warning_threshold_exceeded = [module.vault_secrets.secrets["my_email"]]
        on_failure = [module.vault_secrets.secrets["my_email"]]
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

#   This is hacky for this use case.. it requires the schema to have been created by the notebook task running already
#   In reality i wouldn't do this unless we created the schema through terraform but i wanted to test the alert
data "databricks_schema" "worldcup" {
  name = "${var.catalog_name}.${var.worldcup_schema_name}"
}

resource "databricks_alert_v2" "max_players_exceeded_alert" {
  display_name = "max_players_exceeded_alert"
  warehouse_id = data.databricks_sql_warehouse.default.id

  query_text = <<-EOT
    SELECT COUNT(*) AS records_breached
    FROM ${var.catalog_name}.${var.worldcup_schema_name}.${databricks_job.fifa_ingestion.task[0].notebook_task[0].base_parameters.table}
    WHERE players_used > 26
  EOT

  evaluation = {
    source = {
      name = "records_breached"
    }
    comparison_operator = "GREATER_THAN"
    threshold = {
      value = {
        double_value = 0
      }
    }
    empty_result_state = "OK"

    notification = {
      subscriptions = [
        {
          destination_id = data.terraform_remote_state.provisioning.outputs.administrator_alert_destination_id
        }
      ]
      notify_on_ok = false
    }
  }

  schedule = {
    quartz_cron_schedule = "0 0 8 * * ?"  # every day at 8:00 AM UTC
    timezone_id          = "UTC"
    pause_status         = "UNPAUSED"
  }
}