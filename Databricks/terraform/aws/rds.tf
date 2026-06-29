# ==============================================================================
# rds.tf
# MySQL source system — everything needed to stand up the HR data source.
#
# Resources:
#   aws_security_group          — inbound MySQL access for DMS + Databricks
#   aws_db_parameter_group      — enables row-based binlog for DMS CDC
#   aws_db_instance             — RDS MySQL 8.0 (db.t4g.micro)
#   aws_s3_bucket               — stores DMS CDC Parquet output and checkpoints
#   aws_s3_bucket_public_access_block — blocks all public S3 access
# ==============================================================================

# ==============================================================================
# NETWORKING
# ==============================================================================

resource "aws_security_group" "rds_sg" {
  name        = "rds-sql-sg"
  description = "Allow inbound MySQL traffic from Databricks serverless NAT IPs"

  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    # TODO: In production, restrict to DMS replication instance IP
    # and Databricks serverless egress CIDRs instead of 0.0.0.0/0.
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# RDS PARAMETER GROUP
# Enables row-based binary logging required for DMS CDC.
# Must be attached to the RDS instance before the first DMS task run.
# RDS must be rebooted after apply for binlog_row_image to take effect.
#
# NOTE: log_bin is a static parameter that cannot be set via parameter group.
# It is automatically enabled by RDS when backup_retention_period > 0.
# ==============================================================================

resource "aws_db_parameter_group" "mysql_cdc" {
  name        = "mysql-cdc-params"
  family      = "mysql8.0"
  description = "Enable row-based binlog for DMS CDC"

  parameter {
    name  = "binlog_format"
    value = "ROW"
  }

  parameter {
    name         = "binlog_row_image"
    value        = "FULL"
    apply_method = "pending-reboot"
  }
}

# ==============================================================================
# RDS MYSQL INSTANCE
#
# backup_retention_period = 1 is required — RDS MySQL only enables log_bin
# (binary logging) when automated backups are active. Without this, DMS CDC
# will fail with "Binary Logging must be enabled".
#
# After first apply:
#   1. Reboot the instance to activate binlog_row_image = FULL
#   2. Run: CALL mysql.rds_set_configuration('binlog retention hours', 24);
# ==============================================================================

resource "aws_db_instance" "default" {
  allocated_storage       = 20
  max_allocated_storage   = 100
  db_name                 = "mydb"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t4g.micro"
  username                = "dbadmin"
  password                = var.db_password
  parameter_group_name    = aws_db_parameter_group.mysql_cdc.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  publicly_accessible     = true
  skip_final_snapshot     = true
  backup_retention_period = 1           # enables log_bin — required for DMS CDC
  backup_window           = "03:00-04:00"
}

# Uncomment to stop/start RDS between sessions to save cost (~$15/mo):
# resource "aws_rds_instance_state" "toggle" {
#   identifier = aws_db_instance.default.identifier
#   state      = "stopped"  # change to "available" to restart
# }

# ==============================================================================
# S3 BUCKET
# Stores DMS CDC Parquet output and Auto Loader checkpoints.
# Account ID suffix ensures globally unique name without random drift.
# ==============================================================================

resource "aws_s3_bucket" "main" {
  bucket        = "databricks-${data.aws_caller_identity.current.account_id}"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
