# Auto Scaling Group Example using Golden AMI
# This example deploys an Auto Scaling Group with Application Load Balancer

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Deploy Auto Scaling Group using Golden AMI
module "golden_ami_asg" {
  source = "../../modules/asg-launch-template"

  # Basic configuration
  name        = var.application_name
  environment = var.environment

  # Instance configuration
  instance_type = var.instance_type
  key_name      = var.key_name

  # Auto Scaling Group configuration
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  # Networking
  vpc_id             = var.vpc_id
  availability_zones = var.availability_zones
  subnet_tags        = var.subnet_tags

  # Security
  create_security_group = true
  enable_ssh           = true
  enable_http          = true
  enable_https         = true
  ssh_cidr_blocks      = var.ssh_cidr_blocks

  # Custom security group rules for application
  custom_ingress_rules = var.custom_ports

  # IAM
  create_iam_role = true
  iam_managed_policies = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  # Storage
  block_device_mappings = [
    {
      device_name           = "/dev/sda1"
      volume_type           = "gp3"
      volume_size           = var.root_volume_size
      encrypted             = true
      delete_on_termination = true
      throughput            = null
      iops                  = null
    }
  ]

  # User data for application setup
  user_data = var.user_data

  # Monitoring
  detailed_monitoring = var.detailed_monitoring

  # Auto Scaling Policies
  enable_scaling_policies = var.enable_auto_scaling

  # CloudWatch Alarms thresholds
  cpu_high_threshold = var.scale_up_cpu_threshold
  cpu_low_threshold  = var.scale_down_cpu_threshold

  # Mixed Instance Policy (for cost optimization)
  use_mixed_instances_policy = var.use_mixed_instances

  mixed_instances_overrides = var.use_mixed_instances ? [
    { instance_type = "t3.medium", weighted_capacity = 1 },
    { instance_type = "t3.large", weighted_capacity = 2 },
    { instance_type = "t3a.medium", weighted_capacity = 1 },
    { instance_type = "t3a.large", weighted_capacity = 2 }
  ] : []

  on_demand_percentage_above_base_capacity = var.spot_percentage
  spot_allocation_strategy                 = "capacity-optimized"

  # Instance Refresh for rolling deployments
  instance_refresh = var.enable_instance_refresh ? {
    strategy               = "Rolling"
    instance_warmup        = 300
    min_healthy_percentage = 50
    triggers               = ["launch_template"]
  } : null

  # Target Group ARNs (will be set after ALB creation)
  target_group_arns = [aws_lb_target_group.app.arn]

  # Tags
  tags = merge(var.common_tags, {
    Name        = var.application_name
    Environment = var.environment
    Purpose     = "Auto Scaling Demo"
  })
}

# Application Load Balancer
resource "aws_lb" "app" {
  name               = "${var.application_name}-alb"
  internal           = var.internal_load_balancer
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.common_tags, {
    Name = "${var.application_name}-alb"
  })
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "${var.application_name}-alb-"
  description = "Security group for ${var.application_name} Application Load Balancer"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidr_blocks
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.application_name}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group
resource "aws_lb_target_group" "app" {
  name     = "${var.application_name}-tg"
  port     = var.application_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.selected.id

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = var.health_check_timeout
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }

  tags = merge(var.common_tags, {
    Name = "${var.application_name}-tg"
  })
}

# ALB Listener (HTTP)
resource "aws_lb_listener" "app_http" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ALB Listener (HTTPS) - Optional
resource "aws_lb_listener" "app_https" {
  count = var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.app.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Data sources for networking
data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = var.public_subnet_tags
}

# CloudWatch Dashboard (Optional)
resource "aws_cloudwatch_dashboard" "app" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = "${var.application_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.golden_ami_asg.autoscaling_group_name],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app.arn_suffix],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app.arn_suffix]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
          title   = "Application Metrics"
        }
      }
    ]
  })
}

# Route 53 Record (Optional)
resource "aws_route53_record" "app" {
  count = var.create_route53_record && var.domain_name != null ? 1 : 0

  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.subdomain != null ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}

data "aws_route53_zone" "selected" {
  count = var.create_route53_record && var.domain_name != null ? 1 : 0

  name         = var.domain_name
  private_zone = false
}
