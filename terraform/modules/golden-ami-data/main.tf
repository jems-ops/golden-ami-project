# Golden AMI Data Source Module
# This module finds the latest Golden AMI based on specified filters

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source to find the latest Golden AMI
data "aws_ami" "golden_ami" {
  most_recent = true
  owners      = var.ami_owners

  dynamic "filter" {
    for_each = var.ami_filters
    content {
      name   = filter.value.name
      values = filter.value.values
    }
  }

  # Default filters for Golden AMI
  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Filter by environment tag if specified
  dynamic "filter" {
    for_each = var.environment != null ? [1] : []
    content {
      name   = "tag:Environment"
      values = [var.environment]
    }
  }

  # Filter by purpose tag
  filter {
    name   = "tag:Purpose"
    values = ["Golden AMI"]
  }
}

# Validate that an AMI was found
resource "null_resource" "ami_validation" {
  count = var.validate_ami ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      if [ "${data.aws_ami.golden_ami.id}" = "" ]; then
        echo "Error: No Golden AMI found matching the specified criteria"
        exit 1
      else
        echo "Found Golden AMI: ${data.aws_ami.golden_ami.id} (${data.aws_ami.golden_ami.name})"
      fi
    EOT
  }
}
