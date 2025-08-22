# Terraform configuration for creating IAM roles and policies for Golden AMI building with Packer
# This is an alternative to the CloudFormation template (iam-roles.yml)

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  profile = "cloudcasts"
  region = var.aws_region
}

# Local variables
locals {
  role_name   = var.role_name != null ? var.role_name : "PackerAMIBuilderRole"
  policy_name = var.policy_name != null ? var.policy_name : "PackerAMIBuilderPolicy"

  common_tags = merge(var.tags, {
    Purpose   = "PackerAMIBuilding"
    ManagedBy = "Terraform"
  })
}

# IAM Policy Document for EC2 service to assume the role
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }

  # Allow cross-account assume role if account IDs are provided
  dynamic "statement" {
    for_each = length(var.trusted_account_ids) > 0 ? [1] : []
    content {
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = [for account_id in var.trusted_account_ids : "arn:aws:iam::${account_id}:root"]
      }
      actions = ["sts:AssumeRole"]
      condition {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.external_id]
      }
    }
  }

  # Allow current account root to assume role
  dynamic "statement" {
    for_each = var.allow_current_account_assume ? [1] : []
    content {
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      }
      actions = ["sts:AssumeRole"]
      condition {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.external_id]
      }
    }
  }
}

# Get current AWS account information
data "aws_caller_identity" "current" {}

# IAM Policy Document for Packer permissions
data "aws_iam_policy_document" "packer_permissions" {
  # EC2 Instance Management
  statement {
    sid    = "PackerInstanceManagement"
    effect = "Allow"
    actions = [
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CopyImage",
      "ec2:CreateImage",
      "ec2:CreateKeypair",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteKeyPair",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSnapshot",
      "ec2:DeleteVolume",
      "ec2:DeregisterImage",
      "ec2:DescribeImageAttribute",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeRegions",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSnapshots",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVpcs",
      "ec2:DetachVolume",
      "ec2:GetPasswordData",
      "ec2:ModifyImageAttribute",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifySnapshotAttribute",
      "ec2:RegisterImage",
      "ec2:RunInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances"
    ]
    resources = ["*"]
  }

  # IAM PassRole permissions
  statement {
    sid    = "PackerIAMPassRole"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  # KMS permissions for encrypted volumes
  statement {
    sid    = "PackerKeyManagement"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]
    resources = var.kms_key_arns
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ec2.*.amazonaws.com"]
    }
  }

  # Additional permissions for CloudWatch and SSM (optional)
  dynamic "statement" {
    for_each = var.enable_cloudwatch_logs ? [1] : []
    content {
      sid    = "CloudWatchLogs"
      effect = "Allow"
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      resources = [
        "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/packer/*"
      ]
    }
  }

  dynamic "statement" {
    for_each = var.enable_ssm_access ? [1] : []
    content {
      sid    = "SSMAccess"
      effect = "Allow"
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ]
      resources = [
        "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/packer/*",
        "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/golden-ami/*"
      ]
    }
  }

  # Custom additional permissions
  dynamic "statement" {
    for_each = var.additional_policy_statements
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "condition" {
        for_each = statement.value.conditions != null ? statement.value.conditions : []
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

# IAM Role for Packer
resource "aws_iam_role" "packer_role" {
  name                 = local.role_name
  assume_role_policy   = data.aws_iam_policy_document.ec2_assume_role.json
  max_session_duration = var.max_session_duration
  path                 = var.iam_path

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# IAM Policy for Packer
resource "aws_iam_policy" "packer_policy" {
  name        = local.policy_name
  description = "Policy for Packer to build Golden AMIs"
  policy      = data.aws_iam_policy_document.packer_permissions.json
  path        = var.iam_path

  tags = local.common_tags
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "packer_policy_attachment" {
  role       = aws_iam_role.packer_role.name
  policy_arn = aws_iam_policy.packer_policy.arn
}

# Attach additional managed policies
resource "aws_iam_role_policy_attachment" "additional_policies" {
  count      = length(var.additional_managed_policies)
  role       = aws_iam_role.packer_role.name
  policy_arn = var.additional_managed_policies[count.index]
}

# Instance Profile for EC2 instances (if needed)
resource "aws_iam_instance_profile" "packer_instance_profile" {
  count = var.create_instance_profile ? 1 : 0

  name = "${local.role_name}-InstanceProfile"
  role = aws_iam_role.packer_role.name
  path = var.iam_path

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# Optional: Create a user for programmatic access
resource "aws_iam_user" "packer_user" {
  count = var.create_iam_user ? 1 : 0

  name = "${local.role_name}-User"
  path = var.iam_path

  tags = local.common_tags
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "packer_user_policy" {
  count      = var.create_iam_user ? 1 : 0
  user       = aws_iam_user.packer_user[0].name
  policy_arn = aws_iam_policy.packer_policy.arn
}

# Optional: Create access keys for the user
resource "aws_iam_access_key" "packer_user_key" {
  count = var.create_iam_user && var.create_access_key ? 1 : 0
  user  = aws_iam_user.packer_user[0].name
}

# Store access key in AWS Systems Manager Parameter Store (optional)
resource "aws_ssm_parameter" "access_key_id" {
  count = var.create_iam_user && var.create_access_key && var.store_keys_in_ssm ? 1 : 0

  name        = "/packer/aws_access_key_id"
  description = "AWS Access Key ID for Packer user"
  type        = "String"
  value       = aws_iam_access_key.packer_user_key[0].id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "secret_access_key" {
  count = var.create_iam_user && var.create_access_key && var.store_keys_in_ssm ? 1 : 0

  name        = "/packer/aws_secret_access_key"
  description = "AWS Secret Access Key for Packer user"
  type        = "SecureString"
  value       = aws_iam_access_key.packer_user_key[0].secret

  tags = local.common_tags
}
