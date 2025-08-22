packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# Variables
variable "aws_region" {
  type        = string
  description = "AWS region to build the AMI in"
  default     = "us-east-1"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type to use for building"
  default     = "t3.medium"
}

variable "source_ami_filter" {
  type        = string
  description = "Filter for source AMI"
  default     = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
}

variable "ami_name_prefix" {
  type        = string
  description = "Prefix for AMI name"
  default     = "golden-ami-ubuntu-22.04"
}

variable "environment" {
  type        = string
  description = "Environment tag for the AMI"
  default     = "production"
}

variable "build_user" {
  type        = string
  description = "User building the AMI"
  default     = "unknown"
}

# Data sources
data "amazon-ami" "ubuntu" {
  filters = {
    name                = var.source_ami_filter
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"] # Canonical
  region      = var.aws_region
}

# Local variables
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name  = "${var.ami_name_prefix}-${local.timestamp}"
}

# Build definition
source "amazon-ebs" "ubuntu" {
  ami_name      = local.ami_name
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami    = data.amazon-ami.ubuntu.id
  
  ssh_username = "ubuntu"
  ssh_timeout  = "20m"

  # EBS settings
  ebs_optimized = true
  
  run_tags = {
    Name        = "Packer Builder - ${local.ami_name}"
    Environment = var.environment
    Purpose     = "Golden AMI Build"
  }

  tags = {
    Name            = local.ami_name
    Environment     = var.environment
    OS              = "Ubuntu"
    OSVersion       = "22.04"
    Architecture    = "x86_64"
    BuildDate       = timestamp()
    PackerVersion   = packer.version
    Purpose         = "Golden AMI"
    ManagedBy       = "Packer"
  }

  # Security group for build
  temporary_security_group_source_cidrs = ["0.0.0.0/0"]
}

# Build steps
build {
  name = "golden-ami"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  # Wait for cloud-init to finish
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Cloud-init completed'"
    ]
  }

  # Update system
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y python3-pip python3-dev",
      "sudo pip3 install ansible"
    ]
  }

  # Run Ansible playbook
  provisioner "ansible" {
    playbook_file = "../ansible/playbooks/golden-ami.yml"
    user = "ubuntu"
    extra_arguments = [
      "--extra-vars",
      "target_user=ubuntu"
    ]
  }

  # Final cleanup
  provisioner "shell" {
    inline = [
      "echo 'Running final cleanup...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "history -c && history -w",
      "sudo rm -f /root/.bash_history",
      "sudo rm -f /home/ubuntu/.bash_history",
      "echo 'Cleanup completed'"
    ]
  }

  # Create AMI manifest
  post-processor "manifest" {
    output = "manifest.json"
    strip_path = true
    custom_data = {
      build_time = timestamp()
      build_user = var.build_user
    }
  }
}
