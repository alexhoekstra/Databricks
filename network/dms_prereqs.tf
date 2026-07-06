# ==============================================================================
# dms_prereqs.tf
# AWS requires an account-level role named exactly `dms-vpc-role` (with the
# AmazonDMSVPCManagementRole managed policy) before CreateReplicationSubnetGroup
# succeeds.
# ==============================================================================

data "aws_iam_policy_document" "dms_vpc_trust" {
  statement {
    sid     = "DMSAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["dms.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dms_vpc" {
  count = var.create_dms_vpc_role ? 1 : 0

  name               = "dms-vpc-role" # exact name required by DMS
  assume_role_policy = data.aws_iam_policy_document.dms_vpc_trust.json
  description        = "Account role DMS requires for managing VPC resources (subnet groups)"
}

resource "aws_iam_role_policy_attachment" "dms_vpc" {
  count = var.create_dms_vpc_role ? 1 : 0

  role       = aws_iam_role.dms_vpc[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

resource "time_sleep" "dms_vpc_propagation" {
  count = var.create_dms_vpc_role ? 1 : 0

  create_duration = "15s"

  depends_on = [aws_iam_role_policy_attachment.dms_vpc]
}
