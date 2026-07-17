# iam.tf

# Databricks Trust Policy. 
# (This is the part that the org would need to add to allow your databricks access)
#
# Two-statement trust policy:
#   DatabricksAssume — allows Databricks' AWS control plane to assume this role
#   SelfAssume       — allows the role to assume itself (required by UC validation)

data "aws_iam_policy_document" "databricks_trust" {
  statement {
    sid     = "DatabricksAssume"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::414351767826:root"] # Databricks control-plane AWS account
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.databricks_account_id]
    }
  }

  statement {
    sid     = "SelfAssume"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = [local.databricks_role_arn]
    }
  }
}

# IAM Role for Databricks External Data Access (Federation stuff)
resource "aws_iam_role" "databricks_access" {
  name               = "databricks-external-data-access"
  assume_role_policy = data.aws_iam_policy_document.databricks_trust.json
}

# IAM Policy Document for Databricks External Data Access (Federation Stuff)
data "aws_iam_policy_document" "databricks_s3" {
  statement {
    sid    = "S3BucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.main.arn,
      "${aws_s3_bucket.main.arn}/*",
    ]
  }
  statement {
    sid       = "SelfAssumeRole"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [local.databricks_role_arn]
  }
}

# IAM Policy for Databricks S3 Access (Allow access to parquet files)
resource "aws_iam_policy" "databricks_s3" {
  name   = "databricks-s3-access-policy"
  policy = data.aws_iam_policy_document.databricks_s3.json
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "databricks_s3" {
  role       = aws_iam_role.databricks_access.name
  policy_arn = aws_iam_policy.databricks_s3.arn
}


#######################################################
# Everything Below is likely already setup by the Org
######################################################

# SHARED TRUST DOCUMENT — DMS service principal
# Reused by all three DMS roles below.

data "aws_iam_policy_document" "dms_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dms.amazonaws.com"]
    }
  }
}

# DMS S3 role (Org would likely already do this themselves)
# Allows the DMS replication task to write Parquet CDC files to S3.

resource "aws_iam_role" "dms_s3" {
  name               = "dms-s3-access-role"
  assume_role_policy = data.aws_iam_policy_document.dms_trust.json
}

data "aws_iam_policy_document" "dms_s3" {
  statement {
    sid    = "DMSWriteS3"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.main.arn,
      "${aws_s3_bucket.main.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "dms_s3" {
  name   = "dms-s3-access-policy"
  role   = aws_iam_role.dms_s3.id
  policy = data.aws_iam_policy_document.dms_s3.json
}


# DMS VPC role (Org would likely already do this themselves)
# Required one-time account-level setup for DMS.
resource "aws_iam_role" "dms_vpc" {
  name               = "dms-vpc-role"
  assume_role_policy = data.aws_iam_policy_document.dms_trust.json
}

resource "aws_iam_role_policy_attachment" "dms_vpc" {
  role       = aws_iam_role.dms_vpc.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# Wait for IAM propagation before DMS tries to use this role 
resource "time_sleep" "dms_vpc_propagation" {
  create_duration = "15s"
  depends_on      = [aws_iam_role_policy_attachment.dms_vpc]
}

# DMS CLOUDWATCH role (Org would likely already do this themselves)
# Allows DMS to publish task logs to CloudWatch.
# AWS looks for this role by its exact name — do not rename it.
resource "aws_iam_role" "dms_cloudwatch" {
  name               = "dms-cloudwatch-logs-role"
  assume_role_policy = data.aws_iam_policy_document.dms_trust.json
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch" {
  role       = aws_iam_role.dms_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

resource "time_sleep" "dms_cloudwatch_propagation" {
  create_duration = "15s"
  depends_on      = [aws_iam_role_policy_attachment.dms_cloudwatch]
}
