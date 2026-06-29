# ==============================================================================
# databricks.tf
# All Databricks Unity Catalog and job resources.
#
# AWS values referenced here (IAM role, S3 bucket, RDS endpoint/credentials)
# come from the AWS layer's outputs via local.aws (see main.tf remote state).
# Nothing in this file creates or modifies AWS infrastructure.
#
# Resources:
#   databricks_storage_credential  — UC credential using the Databricks IAM role
#   databricks_external_location   — root S3 path registered in UC
#   databricks_connection          — UC connection to RDS MySQL
#   databricks_schema              — target schema for bronze tables
#   databricks_catalog             — foreign catalog (Lakehouse Federation)
#   databricks_grants              — access grants on catalog and credential
#   databricks_workspace_file      — uploads the cdc_bronze_ingest wheel
#   databricks_job                 — scheduled job running the wheel entry point
# ==============================================================================

# ==============================================================================
# UNITY CATALOG — storage credential
# Links the Databricks IAM role to UC so notebooks and jobs can access S3
# without hardcoding credentials.
# ==============================================================================

resource "databricks_storage_credential" "main" {
  name    = local.aws.databricks_role_name
  comment = "Managed by Terraform — cross-account S3 access via IAM role"

  aws_iam_role {
    role_arn = local.aws.databricks_role_arn
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
  url             = "s3://${local.aws.s3_bucket_name}"
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
    host     = local.aws.db_address
    port     = tostring(local.aws.db_port)
    user     = local.aws.db_username
    password = local.aws.db_password
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
# INGESTION WHEEL
# The Auto Loader ingestion logic is packaged as the cdc_bronze_ingest Python
# wheel (Databricks/notebooks/modules/cdc_bronze_ingest). Build it first:
#   cd ../../../notebooks/modules/cdc_bronze_ingest && python -m build --wheel
# Then this uploads the built artifact to the workspace so the serverless job
# can install it as a library.
# ==============================================================================

resource "databricks_workspace_file" "cdc_wheel" {
  source = local.cdc_wheel_source
  path   = local.cdc_wheel_workspace_path
}

# ==============================================================================
# DATABRICKS JOB — scheduled CDC ingestion
# Runs the cdc_bronze_ingest wheel's entry point on serverless compute
# (client = "2"). Config is passed as named_parameters (--key value), matching
# the wheel's argparse interface.
# Scheduled daily at 6 AM Eastern; trigger manually with:
#   databricks jobs run-now --job-id <ingestion_job_id output>
# ==============================================================================

resource "databricks_job" "cdc_ingestion" {
  name = "hr-rds-cdc-ingestion"

  task {
    task_key = "autoloader_bronze"

    python_wheel_task {
      package_name = "cdc_bronze_ingest"
      entry_point  = "cdc_bronze_ingest" # from [project.scripts] in pyproject.toml
      named_parameters = {
        s3_cdc_prefix   = "s3://${local.aws.s3_bucket_name}/dms-cdc"
        source_schema   = local.aws.db_name
        target_catalog  = "main"
        target_schema   = databricks_schema.staging.name
        checkpoint_base = "s3://${local.aws.s3_bucket_name}/checkpoints/cdc-bronze"
      }
    }

    environment_key = "default"
  }

  environment {
    environment_key = "default"
    spec {
      client = "2"
      # Install the uploaded wheel into the serverless environment. Uses a
      # known-at-plan-time string (not the workspace file's computed
      # workspace_path) to avoid the provider's inconsistent-final-plan error;
      # depends_on below preserves the upload-before-job ordering.
      dependencies = [local.cdc_wheel_wsfs_path]
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
    databricks_workspace_file.cdc_wheel,
  ]
}
