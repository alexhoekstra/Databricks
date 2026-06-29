# ==============================================================================
# databricks.tf
# All Databricks Unity Catalog and job resources.
# AWS resources referenced here are defined in rds.tf and iam.tf.
#
# Resources:
#   databricks_storage_credential  — UC credential using the Databricks IAM role
#   databricks_external_location   — root S3 path registered in UC
#   databricks_connection          — UC connection to RDS MySQL
#   databricks_schema              — target schema for bronze tables
#   databricks_catalog             — foreign catalog (Lakehouse Federation)
#   databricks_grants              — access grants on catalog and credential
#   databricks_notebook            — Auto Loader ingestion notebook
#   databricks_job                 — scheduled job running the notebook
# ==============================================================================

# ==============================================================================
# UNITY CATALOG — storage credential
# Links the Databricks IAM role to UC so notebooks and jobs can access S3
# without hardcoding credentials.
# ==============================================================================

resource "databricks_storage_credential" "main" {
  name    = aws_iam_role.databricks_access.name
  comment = "Managed by Terraform — cross-account S3 access via IAM role"

  aws_iam_role {
    role_arn = aws_iam_role.databricks_access.arn
  }
}

resource "databricks_grants" "storage_credential" {
  storage_credential = databricks_storage_credential.main.id

  grant {
    principal  = var.databricks_user_email
    privileges = ["CREATE_EXTERNAL_TABLE"]
  }
}

# ==============================================================================
# UNITY CATALOG — external location
# Registers the S3 bucket root in UC. Covering the root means all S3 prefixes
# (dms-cdc/, checkpoints/, etc.) are accessible without per-prefix locations.
# ==============================================================================

resource "databricks_external_location" "bucket_root" {
  name            = "databricks-bucket-root"
  url             = "s3://${aws_s3_bucket.main.bucket}"
  credential_name = databricks_storage_credential.main.name
  comment         = "Root external location — covers all prefixes in the S3 bucket"
  skip_validation = true
}

# ==============================================================================
# UNITY CATALOG — RDS MySQL connection
# Used by Lakehouse Federation to query RDS tables directly without ETL.
# Also provides the connection reference for the foreign catalog below.
# ==============================================================================

resource "databricks_connection" "rds_mysql" {
  name            = "rds_mysql_connection"
  connection_type = "MYSQL"
  comment         = "Lakehouse Federation connection to AWS RDS MySQL (i2_playground)"

  options = {
    host     = aws_db_instance.default.address
    port     = tostring(aws_db_instance.default.port)
    user     = aws_db_instance.default.username
    password = aws_db_instance.default.password
  }
}

# ==============================================================================
# UNITY CATALOG — schema
# Target schema where Auto Loader writes bronze Delta tables.
# ==============================================================================

resource "databricks_schema" "staging" {
  catalog_name = "main"
  name         = "lakeflow_staging"
  comment      = "Bronze layer — append-only CDC event log from RDS MySQL via DMS"
}

# ==============================================================================
# UNITY CATALOG — foreign catalog (Lakehouse Federation)
# Mirrors the RDS MySQL database as a read-only UC catalog.
# Tables are immediately queryable as: rds_foreign.mydb.<table>
# No data movement required — queries federate to MySQL at runtime.
# ==============================================================================

resource "databricks_catalog" "rds_foreign" {
  name            = "rds_foreign"
  connection_name = databricks_connection.rds_mysql.name
  comment         = "Foreign catalog mirroring RDS MySQL via Lakehouse Federation"

  depends_on = [databricks_connection.rds_mysql]
}

resource "databricks_grants" "rds_foreign" {
  catalog = databricks_catalog.rds_foreign.name

  grant {
    principal  = var.databricks_user_email
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
}

# ==============================================================================
# INGESTION NOTEBOOK
# Auto Loader notebook uploaded from the local repo to the Databricks workspace.
# Discovers DMS CDC Parquet files in S3 and appends to bronze Delta tables.
# ==============================================================================

resource "databricks_notebook" "autoloader_cdc" {
  path     = "/Shared/autoloader_cdc_bronze.py"
  language = "PYTHON"
  source   = "./config/autoloader_cdc_bronze.py"
}

# ==============================================================================
# DATABRICKS JOB — scheduled CDC ingestion
# Runs the Auto Loader notebook on serverless compute (client = "2").
# Scheduled daily at 6 AM Eastern; trigger manually with:
#   databricks jobs run-now --job-id <ingestion_job_id output>
# ==============================================================================

resource "databricks_job" "cdc_ingestion" {
  name = "hr-rds-cdc-ingestion"

  task {
    task_key = "autoloader_bronze"

    notebook_task {
      notebook_path = databricks_notebook.autoloader_cdc.path
      base_parameters = {
        s3_cdc_prefix   = "s3://${aws_s3_bucket.main.bucket}/dms-cdc"
        source_schema   = aws_db_instance.default.db_name
        target_catalog  = "main"
        target_schema   = databricks_schema.staging.name
        checkpoint_base = "s3://${aws_s3_bucket.main.bucket}/checkpoints/cdc-bronze"
      }
    }

    environment_key = "default"
  }

  environment {
    environment_key = "default"
    spec {
      client       = "2"
      dependencies = []
    }
  }

  schedule {
    quartz_cron_expression = "0 0 6 * * ?"
    timezone_id            = "America/New_York"
    pause_status           = "UNPAUSED"
  }

  email_notifications {
    on_failure = [var.databricks_user_email]
  }

  depends_on = [
    databricks_schema.staging,
    databricks_external_location.bucket_root,
    databricks_notebook.autoloader_cdc,
  ]
}
