# EC2 Instance Module using Golden AMI
# This module creates EC2 instances using the latest Golden AMI

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get the latest Golden AMI
module "golden_ami" {
  source = "../golden-ami-data"

  ami_name_pattern = var.ami_name_pattern
  environment      = var.environment
  ami_owners       = var.ami_owners
  ami_filters      = var.ami_filters
  validate_ami     = var.validate_ami

  tags = var.tags
}

# Get VPC data if VPC ID is provided
data "aws_vpc" "selected" {
  count = var.vpc_id != null ? 1 : 0
  id    = var.vpc_id
}

# Get default VPC if no VPC specified
data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

# Get subnets
data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id]
  }

  filter {
    name   = "availability-zone"
    values = var.availability_zones
  }

  tags = var.subnet_tags
}

# Security Group for EC2 instances
resource "aws_security_group" "ec2" {
  count = var.create_security_group ? 1 : 0

  name_prefix = "${var.name}-ec2-"
  description = "Security group for ${var.name} EC2 instances"
  vpc_id      = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id

  # SSH access
  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_cidr_blocks
    }
  }

  # HTTP access
  dynamic "ingress" {
    for_each = var.enable_http ? [1] : []
    content {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = var.http_cidr_blocks
    }
  }

  # HTTPS access
  dynamic "ingress" {
    for_each = var.enable_https ? [1] : []
    content {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.https_cidr_blocks
    }
  }

  # Custom ingress rules
  dynamic "ingress" {
    for_each = var.custom_ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  # Egress rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-ec2-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# IAM role for EC2 instances
resource "aws_iam_role" "ec2" {
  count = var.create_iam_role ? 1 : 0

  name_prefix = "${var.name}-ec2-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach managed policies to the role
resource "aws_iam_role_policy_attachment" "ec2_managed" {
  count = var.create_iam_role ? length(var.iam_managed_policies) : 0

  role       = aws_iam_role.ec2[0].name
  policy_arn = var.iam_managed_policies[count.index]
}

# Custom IAM policy for the role
resource "aws_iam_role_policy" "ec2_custom" {
  count = var.create_iam_role && var.iam_custom_policy != null ? 1 : 0

  name_prefix = "${var.name}-ec2-policy-"
  role        = aws_iam_role.ec2[0].id
  policy      = var.iam_custom_policy
}

# Instance profile
resource "aws_iam_instance_profile" "ec2" {
  count = var.create_iam_role ? 1 : 0

  name_prefix = "${var.name}-ec2-profile-"
  role        = aws_iam_role.ec2[0].name

  tags = var.tags
}

# Key pair for SSH access
resource "aws_key_pair" "ec2" {
  count = var.create_key_pair && var.public_key != null ? 1 : 0

  key_name_prefix = "${var.name}-ec2-"
  public_key      = var.public_key

  tags = var.tags
}

# EC2 instances
resource "aws_instance" "ec2" {
  count = var.instance_count

  ami           = module.golden_ami.ami_id
  instance_type = var.instance_type

  # Placement
  subnet_id                   = element(data.aws_subnets.selected.ids, count.index)
  availability_zone           = element(var.availability_zones, count.index)
  associate_public_ip_address = var.associate_public_ip_address

  # Security
  vpc_security_group_ids = concat(
    var.create_security_group ? [aws_security_group.ec2[0].id] : [],
    var.additional_security_group_ids
  )
  key_name = var.key_name != null ? var.key_name : (
    var.create_key_pair && var.public_key != null ? aws_key_pair.ec2[0].key_name : null
  )

  # IAM
  iam_instance_profile = var.create_iam_role ? aws_iam_instance_profile.ec2[0].name : var.iam_instance_profile

  # Storage
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted             = var.root_volume_encrypted
    delete_on_termination = var.root_delete_on_termination

    tags = merge(var.tags, {
      Name = "${var.name}-${count.index + 1}-root"
    })
  }

  # Additional EBS volumes
  dynamic "ebs_block_device" {
    for_each = var.ebs_block_devices
    content {
      device_name           = ebs_block_device.value.device_name
      volume_type           = ebs_block_device.value.volume_type
      volume_size           = ebs_block_device.value.volume_size
      encrypted             = ebs_block_device.value.encrypted
      delete_on_termination = ebs_block_device.value.delete_on_termination

      tags = merge(var.tags, {
        Name = "${var.name}-${count.index + 1}-${ebs_block_device.value.device_name}"
      })
    }
  }

  # User data
  user_data                   = var.user_data
  user_data_base64            = var.user_data_base64
  user_data_replace_on_change = var.user_data_replace_on_change

  # Other settings
  monitoring                 = var.detailed_monitoring
  disable_api_termination    = var.disable_api_termination
  instance_initiated_shutdown_behavior = var.instance_initiated_shutdown_behavior

  # Tags
  tags = merge(var.tags, {
    Name = var.instance_count > 1 ? "${var.name}-${count.index + 1}" : var.name
  })

  volume_tags = var.tags

  lifecycle {
    ignore_changes = [
      ami,  # Ignore AMI changes to prevent unwanted replacements
    ]
  }
}

# Elastic IPs (optional)
resource "aws_eip" "ec2" {
  count = var.create_elastic_ips ? var.instance_count : 0

  instance = aws_instance.ec2[count.index].id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = var.instance_count > 1 ? "${var.name}-eip-${count.index + 1}" : "${var.name}-eip"
  })

  depends_on = [aws_instance.ec2]
}
