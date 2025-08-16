# Auto Scaling Group with Launch Template Module using Golden AMI
# This module creates ASG and Launch Template using the latest Golden AMI

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

# Get VPC data
data "aws_vpc" "selected" {
  count = var.vpc_id != null ? 1 : 0
  id    = var.vpc_id
}

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

  dynamic "filter" {
    for_each = length(var.availability_zones) > 0 ? [1] : []
    content {
      name   = "availability-zone"
      values = var.availability_zones
    }
  }

  tags = var.subnet_tags
}

# Security Group for instances
resource "aws_security_group" "asg" {
  count = var.create_security_group ? 1 : 0

  name_prefix = "${var.name}-asg-"
  description = "Security group for ${var.name} Auto Scaling Group instances"
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-asg-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# IAM role for EC2 instances
resource "aws_iam_role" "asg" {
  count = var.create_iam_role ? 1 : 0

  name_prefix = "${var.name}-asg-role-"

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
resource "aws_iam_role_policy_attachment" "asg_managed" {
  count = var.create_iam_role ? length(var.iam_managed_policies) : 0

  role       = aws_iam_role.asg[0].name
  policy_arn = var.iam_managed_policies[count.index]
}

# Custom IAM policy for the role
resource "aws_iam_role_policy" "asg_custom" {
  count = var.create_iam_role && var.iam_custom_policy != null ? 1 : 0

  name_prefix = "${var.name}-asg-policy-"
  role        = aws_iam_role.asg[0].id
  policy      = var.iam_custom_policy
}

# Instance profile
resource "aws_iam_instance_profile" "asg" {
  count = var.create_iam_role ? 1 : 0

  name_prefix = "${var.name}-asg-profile-"
  role        = aws_iam_role.asg[0].name

  tags = var.tags
}

# Launch Template
resource "aws_launch_template" "asg" {
  name_prefix   = "${var.name}-lt-"
  image_id      = module.golden_ami.ami_id
  instance_type = var.instance_type

  # Key pair
  key_name = var.key_name

  # VPC Security Groups
  vpc_security_group_ids = concat(
    var.create_security_group ? [aws_security_group.asg[0].id] : [],
    var.additional_security_group_ids
  )

  # IAM Instance Profile
  dynamic "iam_instance_profile" {
    for_each = var.create_iam_role || var.iam_instance_profile != null ? [1] : []
    content {
      name = var.create_iam_role ? aws_iam_instance_profile.asg[0].name : var.iam_instance_profile
    }
  }

  # Block device mappings
  dynamic "block_device_mappings" {
    for_each = var.block_device_mappings
    content {
      device_name = block_device_mappings.value.device_name

      ebs {
        volume_type           = block_device_mappings.value.volume_type
        volume_size           = block_device_mappings.value.volume_size
        encrypted             = block_device_mappings.value.encrypted
        delete_on_termination = block_device_mappings.value.delete_on_termination
        throughput            = block_device_mappings.value.throughput
        iops                  = block_device_mappings.value.iops
      }
    }
  }

  # User data
  user_data = var.user_data_base64 != null ? var.user_data_base64 : (
    var.user_data != null ? base64encode(var.user_data) : null
  )

  # Instance requirements (for mixed instance types)
  dynamic "instance_requirements" {
    for_each = var.use_mixed_instances_policy ? [1] : []
    content {
      memory_mib {
        min = var.instance_requirements.memory_mib_min
        max = var.instance_requirements.memory_mib_max
      }
      vcpu_count {
        min = var.instance_requirements.vcpu_count_min
        max = var.instance_requirements.vcpu_count_max
      }
      instance_generations = var.instance_requirements.instance_generations
    }
  }

  # Monitoring
  monitoring {
    enabled = var.detailed_monitoring
  }

  # Metadata options
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Network interfaces (for specific subnet placement)
  dynamic "network_interfaces" {
    for_each = var.associate_public_ip_address ? [1] : []
    content {
      associate_public_ip_address = var.associate_public_ip_address
      security_groups = concat(
        var.create_security_group ? [aws_security_group.asg[0].id] : [],
        var.additional_security_group_ids
      )
      delete_on_termination = true
    }
  }

  # Tags
  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = var.name
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = var.tags
  }

  tags = merge(var.tags, {
    Name = "${var.name}-launch-template"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "asg" {
  name                = "${var.name}-asg"
  vpc_zone_identifier = var.subnet_ids != null ? var.subnet_ids : data.aws_subnets.selected.ids
  
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period
  default_cooldown          = var.default_cooldown

  # Launch Template configuration
  dynamic "launch_template" {
    for_each = !var.use_mixed_instances_policy ? [1] : []
    content {
      id      = aws_launch_template.asg.id
      version = var.launch_template_version
    }
  }

  # Mixed Instances Policy (for Spot instances and instance diversification)
  dynamic "mixed_instances_policy" {
    for_each = var.use_mixed_instances_policy ? [1] : []
    content {
      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.asg.id
          version            = var.launch_template_version
        }

        dynamic "override" {
          for_each = var.mixed_instances_overrides
          content {
            instance_type     = override.value.instance_type
            weighted_capacity = override.value.weighted_capacity
          }
        }
      }

      instances_distribution {
        on_demand_allocation_strategy            = var.on_demand_allocation_strategy
        on_demand_base_capacity                  = var.on_demand_base_capacity
        on_demand_percentage_above_base_capacity = var.on_demand_percentage_above_base_capacity
        spot_allocation_strategy                 = var.spot_allocation_strategy
        spot_instance_pools                      = var.spot_instance_pools
        spot_max_price                          = var.spot_max_price
      }
    }
  }

  # Target Group ARNs (for ALB/NLB integration)
  target_group_arns = var.target_group_arns

  # Load Balancer Names (for Classic Load Balancer)
  load_balancers = var.load_balancer_names

  # Termination policies
  termination_policies = var.termination_policies

  # Instance refresh
  dynamic "instance_refresh" {
    for_each = var.instance_refresh != null ? [var.instance_refresh] : []
    content {
      strategy = instance_refresh.value.strategy
      preferences {
        instance_warmup        = instance_refresh.value.instance_warmup
        min_healthy_percentage = instance_refresh.value.min_healthy_percentage
      }
      triggers = instance_refresh.value.triggers
    }
  }

  # Warm pool
  dynamic "warm_pool" {
    for_each = var.warm_pool != null ? [var.warm_pool] : []
    content {
      pool_state                  = warm_pool.value.pool_state
      min_size                   = warm_pool.value.min_size
      max_group_prepared_capacity = warm_pool.value.max_group_prepared_capacity
    }
  }

  # Tags
  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = var.propagate_tags_at_launch
    }
  }

  # Additional tags
  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      load_balancers,
      target_group_arns,
    ]
  }

  depends_on = [aws_launch_template.asg]
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  count = var.enable_scaling_policies ? 1 : 0

  name                   = "${var.name}-scale-up"
  scaling_adjustment     = var.scale_up_adjustment
  adjustment_type        = var.scale_up_adjustment_type
  cooldown               = var.scale_up_cooldown
  autoscaling_group_name = aws_autoscaling_group.asg.name
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  count = var.enable_scaling_policies ? 1 : 0

  name                   = "${var.name}-scale-down"
  scaling_adjustment     = var.scale_down_adjustment
  adjustment_type        = var.scale_down_adjustment_type
  cooldown               = var.scale_down_cooldown
  autoscaling_group_name = aws_autoscaling_group.asg.name
  policy_type            = "SimpleScaling"
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.enable_scaling_policies ? 1 : 0

  alarm_name          = "${var.name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cpu_high_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.cpu_high_period
  statistic           = "Average"
  threshold           = var.cpu_high_threshold
  alarm_description   = "This metric monitors ec2 cpu utilization"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_up[0].arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  count = var.enable_scaling_policies ? 1 : 0

  alarm_name          = "${var.name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.cpu_low_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.cpu_low_period
  statistic           = "Average"
  threshold           = var.cpu_low_threshold
  alarm_description   = "This metric monitors ec2 cpu utilization"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_down[0].arn]

  tags = var.tags
}
