# AWS Region
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Instance Configuration
variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "golden-ami-demo"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

# Networking
variable "vpc_id" {
  description = "VPC ID (uses default VPC if not specified)"
  type        = string
  default     = null
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address"
  type        = bool
  default     = true
}

# Security
variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = null
}

variable "enable_http" {
  description = "Enable HTTP access"
  type        = bool
  default     = true
}

variable "enable_https" {
  description = "Enable HTTPS access"
  type        = bool
  default     = true
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Storage
variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
}

variable "create_data_volume" {
  description = "Whether to create an additional data volume"
  type        = bool
  default     = false
}

variable "data_volume_size" {
  description = "Size of the data volume in GB"
  type        = number
  default     = 100
}

# User Data
variable "user_data" {
  description = "User data script for instance initialization"
  type        = string
  default     = <<-EOF
    #!/bin/bash
    # Update system
    apt-get update -y
    
    # Install nginx
    apt-get install -y nginx
    
    # Start nginx
    systemctl start nginx
    systemctl enable nginx
    
    # Create a simple index page
    cat > /var/www/html/index.html << 'HTML'
    <!DOCTYPE html>
    <html>
    <head>
        <title>Golden AMI Demo</title>
    </head>
    <body>
        <h1>Hello from Golden AMI!</h1>
        <p>This instance was launched using a Golden AMI built with Packer and Ansible.</p>
        <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
        <p>Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
    </body>
    </html>
    HTML
    
    # Restart nginx
    systemctl restart nginx
  EOF
}

# Monitoring
variable "detailed_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}

# Elastic IP
variable "create_elastic_ip" {
  description = "Whether to create an Elastic IP"
  type        = bool
  default     = false
}

# Load Balancer
variable "create_load_balancer" {
  description = "Whether to create an Application Load Balancer"
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Health check path for the load balancer"
  type        = string
  default     = "/"
}

# Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Golden AMI Demo"
    ManagedBy   = "Terraform"
    Environment = "development"
  }
}
