# ==============================================================================
# iam.tf
# All IAM — roles, policies, trust documents, and attachments.
# Centralised here so permission debugging has a single file to check.
#
# Roles provisioned:
#   databricks-external-data-access — Databricks cross-account S3 access
#   dms-s3-access-role              — DMS write access to S3
#   dms-vpc-role                    — required one-time DMS account setup
#   dms-cloudwatch-logs-role        — DMS CloudWatch logging
# ==============================================================================

# ==============================================================================
# SHARED TRUST DOCUMENT — DMS service principal
# Reused by all three DMS roles below.
# ==============================================================================

data "aws_iam_policy_document" "dms_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dms.amazonaws.com"]
    }
  }
}

# ==============================================================================
# DATABRICKS CROSS-ACCOUNT ROLE
# Assumed by Databricks Unity Catalog to read/write S3.
#
# Two-statement trust policy:
#   DatabricksAssume — allows Databricks' AWS control plane to assume this role
#   SelfAssume       — allows the role to assume itself (required by UC validation)
#
# Both statements apply in a single `terraform apply`. The SelfAssume statement
# does NOT name the role's own ARN as a principal (IAM rejects principal ARNs
# that don't exist yet — the old chicken-and-egg). Instead its principal is the
# account root, which always exists, and it is narrowed to this one role via an
# aws:PrincipalArn condition. Conditions are string matches and are not validated
# against existing principals, so no comment-out / re-apply is needed.
# This mirrors the pattern in the Databricks Unity Catalog setup docs.
# ==============================================================================

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

resource "aws_iam_role" "databricks_access" {
  name               = "databricks-external-data-access"
  assume_role_policy = data.aws_iam_policy_document.databricks_trust.json
}

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
}

resource "aws_iam_policy" "databricks_s3" {
  name   = "databricks-s3-access-policy"
  policy = data.aws_iam_policy_document.databricks_s3.json
}

resource "aws_iam_role_policy_attachment" "databricks_s3" {
  role       = aws_iam_role.databricks_access.name
  policy_arn = aws_iam_policy.databricks_s3.arn
}

# ==============================================================================
# DMS S3 ROLE
# Allows the DMS replication task to write Parquet CDC files to S3.
# ==============================================================================

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

# ==============================================================================
# DMS VPC ROLE
# Required one-time account-level setup for DMS.
# AWS looks for this role by its exact name — do not rename it.
# ==============================================================================

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

# ==============================================================================
# DMS CLOUDWATCH ROLE
# Allows DMS to publish task logs to CloudWatch.
# AWS looks for this role by its exact name — do not rename it.
# ==============================================================================

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
