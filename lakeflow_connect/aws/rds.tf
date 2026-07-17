# rds.tf
# MySQL source system for DMS CDC - This would exist already

# Networking
resource "aws_security_group" "rds_sg" {
  name        = "rds-sql-sg"
  description = "Allow inbound MySQL traffic from Databricks serverless NAT IPs"

  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    # TODO: Dont allow all, restrict to DMS replication instance IP instead of 0.0.0.0/0.
    # Would likely need an Egress to databricks for Federation as well
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS parameter group
# Enables row-based binary logging required for DMS CDC.
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

# RDS MYSQL Instance
# backup_retention_period = 1 is required otherwise the task fails
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
  backup_retention_period = 1
  backup_window           = "03:00-04:00"
}

# Uncomment to stop/start RDS between sessions to save cost (I'm using free tier!):
# resource "aws_rds_instance_state" "toggle" {
#   identifier = aws_db_instance.default.identifier
#   state      = "stopped"  # change to "available" to restart
# }

# S3 Bucket
# Stores DMS CDC Parquet output and Auto Loader checkpoints.
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
