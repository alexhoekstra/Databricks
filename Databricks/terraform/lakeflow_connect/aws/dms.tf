# ==============================================================================
# dms.tf
# AWS DMS CDC pipeline: RDS MySQL → S3 (Parquet)
# IAM roles referenced here are defined in iam.tf.
#
# Flow:
#   RDS MySQL (binlog ON via rds.tf parameter group)
#     └── DMS Replication Instance
#           ├── Source endpoint → RDS MySQL
#           └── Target endpoint → S3 (Parquet, partitioned by date)
#                 └── s3://<bucket>/dms-cdc/mydb/<table>/YYYY/MM/DD/*.parquet
#
# DMS migration type = full-load-and-cdc:
#   Phase 1: full load — snapshots all existing rows to S3
#   Phase 2: CDC      — streams binlog change events (Op: I/U/D) continuously
#
# After terraform apply:
#   Start the task manually (Terraform does not auto-start replication tasks):
#     aws dms start-replication-task \
#       --replication-task-arn <dms_task_arn output> \
#       --start-replication-task-type start-replication
#
#   To force a fresh full load after the task has previously run:
#     aws dms start-replication-task \
#       --replication-task-arn <dms_task_arn output> \
#       --start-replication-task-type reload-target
#
# Cost: dms.t3.small ~$0.04/hr. Stop the task when not demoing.
# ==============================================================================

# ==============================================================================
# REPLICATION INSTANCE
# Waits for both DMS service roles to propagate before creation.
# ==============================================================================

resource "aws_dms_replication_instance" "main" {
  replication_instance_id    = "hr-cdc-replication"
  replication_instance_class = "dms.t3.small"
  allocated_storage          = 20
  publicly_accessible        = true
  auto_minor_version_upgrade = true
  multi_az                   = false

  depends_on = [
    time_sleep.dms_vpc_propagation,
    time_sleep.dms_cloudwatch_propagation,
  ]
}

# ==============================================================================
# SOURCE ENDPOINT — RDS MySQL
# ==============================================================================

resource "aws_dms_endpoint" "rds_source" {
  endpoint_id   = "hr-rds-source"
  endpoint_type = "source"
  engine_name   = "mysql"

  server_name   = aws_db_instance.default.address
  port          = aws_db_instance.default.port
  database_name = aws_db_instance.default.db_name
  username      = aws_db_instance.default.username
  password      = aws_db_instance.default.password

  # eventsPollInterval: how often DMS polls the binlog (seconds)
  extra_connection_attributes = "eventsPollInterval=5;"
}

# ==============================================================================
# TARGET ENDPOINT — S3 (Parquet)
# Uses aws_dms_s3_endpoint (required for AWS provider v6+).
# s3_settings block was removed in provider v6.
# ==============================================================================

resource "aws_dms_s3_endpoint" "s3_target" {
  endpoint_id             = "hr-s3-target"
  endpoint_type           = "target"
  service_access_role_arn = aws_iam_role.dms_s3.arn

  bucket_name   = aws_s3_bucket.main.bucket
  bucket_folder = "dms-cdc"

  data_format                      = "parquet"
  parquet_version                  = "parquet-2-0"
  parquet_timestamp_in_millisecond = true

  include_op_for_full_load = true   # adds Op column (I/U/D) to every row

  date_partition_enabled  = true
  date_partition_sequence = "YYYYMMDD"

  compression_type       = "GZIP"
  cdc_max_batch_interval = 60      # flush to S3 every 60 seconds
  cdc_min_file_size      = 32000   # or when file reaches 32MB
}

# ==============================================================================
# REPLICATION TASK
# Replicates all tables in the mydb schema.
# Add transformation rules to rename or exclude specific tables.
# ==============================================================================

resource "aws_dms_replication_task" "hr_cdc" {
  replication_task_id      = "hr-mysql-to-s3-cdc"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.rds_source.endpoint_arn
  target_endpoint_arn      = aws_dms_s3_endpoint.s3_target.endpoint_arn
  migration_type           = "full-load-and-cdc"

  table_mappings = jsonencode({
    rules = [
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "include-all-tables"
        object-locator = {
          schema-name = aws_db_instance.default.db_name
          table-name  = "%"
        }
        rule-action = "include"
      }
    ]
  })

  replication_task_settings = jsonencode({
    TargetMetadata = {
      TargetSchema       = ""
      SupportLobs        = true
      FullLobMode        = false
      LobChunkSize       = 64
      LimitedSizeLobMode = true
      LobMaxSize         = 32
    }
    FullLoadSettings = {
      TargetTablePrepMode             = "DROP_AND_CREATE"
      CreatePkAfterFullLoad           = false
      StopTaskCachedChangesApplied    = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks             = 8
      TransactionConsistencyTimeout   = 600
      CommitRate                      = 50000
    }
    Logging = {
      EnableLogging    = true
      EnableLogContext = true
      LogComponents = [
        { Id = "SOURCE_UNLOAD",  Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "SOURCE_CAPTURE", Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "TARGET_LOAD",    Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "TASK_MANAGER",   Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "COMMON",         Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" }
      ]
    }
  })

  depends_on = [
    aws_dms_replication_instance.main,
    aws_dms_endpoint.rds_source,
    aws_dms_s3_endpoint.s3_target,
  ]
}
