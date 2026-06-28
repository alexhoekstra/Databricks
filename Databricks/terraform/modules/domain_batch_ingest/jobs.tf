resource "databricks_job" "domain_batch_ingest" {
  name = "${var.domain}-batch-ingest"

  task {
    task_key = "autoload"
    environment_key = "auto_ingest"
    depends_on { task_key = "extract" }
    python_wheel_task {
      package_name = "domain_batch_ingest"
      entry_point  = "generic_autoloader"
      named_parameters = {
        source_config = var.source_config
        source_path = databricks_volume.raw_volume.volume_path
        schema = databricks_schema.domain_schema.name
        catalog = var.target_catalog
        mode = var.mode
      }
    }
  }

  task {
    task_key = "extract"
    environment_key = "auto_ingest"
    python_wheel_task {
      package_name = "domain_batch_ingest"
      entry_point  = "generic_extractor"
      named_parameters = {
        source_config = var.source_config
        source_type   = var.source_type
        landing_path  = databricks_volume.raw_volume.volume_path
      }
    }
  }

  # Conditionally include the run_as block if sp was set
  dynamic "run_as" {
    for_each = var.sp != null ? [var.sp] : []
    content {
      service_principal_name = data.databricks_service_principal.sp[0].application_id
    }
  }

  schedule {
    quartz_cron_expression = var.schedule
    timezone_id = "America/New_York"
    pause_status = "PAUSED"
  }

  environment {
        environment_key = "auto_ingest"
        spec {
            client       = "2" 
            dependencies = ["kagglehub", "huggingface_hub", "/Workspace/Shared/modules/domain_batch_ingest/domain_batch_ingest-${var.wheel_version}-py3-none-any.whl"] #this can be done better, it should be dynamic not for all jobs
        }
  } 

  depends_on = [ databricks_volume.raw_volume ]
}