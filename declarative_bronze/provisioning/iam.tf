# ==============================================================================
# iam.tf
# ==============================================================================

data "aws_iam_policy_document" "uc_trust" {
  statement {
    sid     = "DatabricksAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

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
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = [local.uc_role_arn]
    }
  }
}

resource "aws_iam_role" "uc" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.uc_trust.json
  description        = "Databricks Unity Catalog read access to declarative_bronze landing buckets"
}

data "aws_iam_policy_document" "uc_s3" {
  statement {
    sid       = "ReadLandingBuckets"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation"]
    resources = concat(local.bucket_arns, local.bucket_arns_obj)
  }

  statement {
    sid       = "SelfAssumeRole"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [local.uc_role_arn]
  }
}

resource "aws_iam_role_policy" "uc_s3" {
  name   = "${var.role_name}-s3"
  role   = aws_iam_role.uc.id
  policy = data.aws_iam_policy_document.uc_s3.json
}
