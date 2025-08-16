# Single EC2 Instance Example using Golden AMI
# This example deploys a single EC2 instance using the latest Golden AMI

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

# Deploy a single EC2 instance using Golden AMI
module "golden_ami_instance" {
  source = "../../modules/ec2-instance"

  # Basic configuration
  name        = var.instance_name
  environment = var.environment

  # Instance configuration
  instance_type   = var.instance_type
  instance_count  = 1
  
  # Networking
  vpc_id                      = var.vpc_id
  availability_zones          = var.availability_zones
  associate_public_ip_address = var.associate_public_ip_address

  # Security
  create_security_group = true
  enable_ssh           = true
  enable_http          = var.enable_http
  enable_https         = var.enable_https
  ssh_cidr_blocks      = var.ssh_cidr_blocks

  # Key pair
  key_name = var.key_name

  # IAM
  create_iam_role = true
  iam_managed_policies = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  # Storage
  root_volume_type      = "gp3"
  root_volume_size      = var.root_volume_size
  root_volume_encrypted = true

  # Additional EBS volumes (optional)
  ebs_block_devices = var.create_data_volume ? [
    {
      device_name           = "/dev/sdf"
      volume_type           = "gp3"
      volume_size           = var.data_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  ] : []

  # User data for instance initialization
  user_data = var.user_data

  # Monitoring
  detailed_monitoring = var.detailed_monitoring

  # Elastic IP
  create_elastic_ips = var.create_elastic_ip

  # Tags
  tags = merge(var.common_tags, {
    Name        = var.instance_name
    Environment = var.environment
    Purpose     = "Single Instance Demo"
  })
}

# Optional: Application Load Balancer for the instance
resource "aws_lb" "app" {
  count = var.create_load_balancer ? 1 : 0

  name               = "${var.instance_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.golden_ami_instance.security_group_id]
  subnets            = module.golden_ami_instance.subnet_ids

  enable_deletion_protection = false

  tags = merge(var.common_tags, {
    Name = "${var.instance_name}-alb"
  })
}

# Target Group for ALB
resource "aws_lb_target_group" "app" {
  count = var.create_load_balancer ? 1 : 0

  name     = "${var.instance_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.golden_ami_instance.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.common_tags, {
    Name = "${var.instance_name}-tg"
  })
}

# ALB Listener
resource "aws_lb_listener" "app" {
  count = var.create_load_balancer ? 1 : 0

  load_balancer_arn = aws_lb.app[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }
}

# Attach instance to target group
resource "aws_lb_target_group_attachment" "app" {
  count = var.create_load_balancer ? 1 : 0

  target_group_arn = aws_lb_target_group.app[0].arn
  target_id        = module.golden_ami_instance.instance_ids[0]
  port             = 80
}
