resource "databricks_job" "domain_batch_ingest" {
  name = "${var.domain}-batch-ingest"

  task {
    task_key = "autoload"
    depends_on { task_key = "extract" }
    notebook_task {
      notebook_path = "/Shared/scalable_ingestion/generic_autoloader"
      base_parameters = {
        source_config = var.source_config
        source_path  = databricks_volume.raw_volume.volume_path
        schema = databricks_schema.domain_schema.name
        catalog = var.target_catalog
      }
    }
  }

  task {
    task_key = "extract"
    environment_key = "default"
    notebook_task {
      notebook_path = "/Shared/scalable_ingestion/generic_extractor"
      base_parameters = {
        source_config = var.source_config
        source_type   = var.source_type
        landing_path  = databricks_volume.raw_volume.volume_path
      }
    }
  }

  schedule {
    quartz_cron_expression = var.schedule
    timezone_id = "America/New_York"
    pause_status = "PAUSED"
  }

  environment {
        environment_key = "default"
        spec {
            client       = "2" 
            dependencies = ["kagglehub", "huggingface_hub"] #this can be done better, it should be dynamic not for all jobs
        }
  } 

  depends_on = [ databricks_volume.raw_volume ]
}