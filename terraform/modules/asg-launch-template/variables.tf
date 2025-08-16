# Golden AMI configuration
variable "ami_name_pattern" {
  description = "Pattern to match AMI names"
  type        = string
  default     = "golden-ami-ubuntu-22.04-*"
}

variable "ami_owners" {
  description = "List of AMI owners to search within"
  type        = list(string)
  default     = ["self"]
}

variable "ami_filters" {
  description = "Additional filters to apply when searching for AMIs"
  type = list(object({
    name   = string
    values = list(string)
  }))
  default = []
}

variable "validate_ami" {
  description = "Whether to validate that an AMI was found"
  type        = bool
  default     = true
}

# General configuration
variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = null
}

# Launch Template configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Key pair name for SSH access"
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script"
  type        = string
  default     = null
}

variable "user_data_base64" {
  description = "Base64 encoded user data"
  type        = string
  default     = null
}

variable "detailed_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}

# Networking
variable "vpc_id" {
  description = "VPC ID to launch instances in (uses default VPC if not specified)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ASG (will discover subnets if not provided)"
  type        = list(string)
  default     = null
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = []
}

variable "subnet_tags" {
  description = "Tags to filter subnets"
  type        = map(string)
  default     = {}
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address"
  type        = bool
  default     = false
}

# Security Group
variable "create_security_group" {
  description = "Whether to create a security group"
  type        = bool
  default     = true
}

variable "additional_security_group_ids" {
  description = "List of additional security group IDs to attach"
  type        = list(string)
  default     = []
}

variable "enable_ssh" {
  description = "Enable SSH access"
  type        = bool
  default     = true
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_http" {
  description = "Enable HTTP access"
  type        = bool
  default     = false
}

variable "http_cidr_blocks" {
  description = "CIDR blocks for HTTP access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_https" {
  description = "Enable HTTPS access"
  type        = bool
  default     = false
}

variable "https_cidr_blocks" {
  description = "CIDR blocks for HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "custom_ingress_rules" {
  description = "List of custom ingress rules"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

# IAM
variable "create_iam_role" {
  description = "Whether to create an IAM role"
  type        = bool
  default     = false
}

variable "iam_instance_profile" {
  description = "IAM instance profile to attach (used if create_iam_role is false)"
  type        = string
  default     = null
}

variable "iam_managed_policies" {
  description = "List of managed policy ARNs to attach to the role"
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

variable "iam_custom_policy" {
  description = "Custom IAM policy document"
  type        = string
  default     = null
}

# Block Device Mappings
variable "block_device_mappings" {
  description = "List of block device mappings"
  type = list(object({
    device_name           = string
    volume_type           = string
    volume_size           = number
    encrypted             = bool
    delete_on_termination = bool
    throughput            = optional(number)
    iops                  = optional(number)
  }))
  default = [
    {
      device_name           = "/dev/sda1"
      volume_type           = "gp3"
      volume_size           = 20
      encrypted             = true
      delete_on_termination = true
      throughput            = null
      iops                  = null
    }
  ]
}

# Auto Scaling Group configuration
variable "min_size" {
  description = "Minimum size of the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum size of the Auto Scaling Group"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "health_check_type" {
  description = "Type of health check"
  type        = string
  default     = "EC2"
}

variable "health_check_grace_period" {
  description = "Health check grace period"
  type        = number
  default     = 300
}

variable "default_cooldown" {
  description = "Default cooldown period"
  type        = number
  default     = 300
}

variable "launch_template_version" {
  description = "Launch template version to use"
  type        = string
  default     = "$Latest"
}

variable "termination_policies" {
  description = "List of termination policies"
  type        = list(string)
  default     = ["Default"]
}

variable "target_group_arns" {
  description = "List of target group ARNs for ALB/NLB"
  type        = list(string)
  default     = []
}

variable "load_balancer_names" {
  description = "List of load balancer names for Classic Load Balancer"
  type        = list(string)
  default     = []
}

# Mixed Instances Policy
variable "use_mixed_instances_policy" {
  description = "Whether to use mixed instances policy"
  type        = bool
  default     = false
}

variable "mixed_instances_overrides" {
  description = "List of instance type overrides for mixed instances policy"
  type = list(object({
    instance_type     = string
    weighted_capacity = optional(number)
  }))
  default = []
}

variable "on_demand_allocation_strategy" {
  description = "On-demand allocation strategy"
  type        = string
  default     = "prioritized"
}

variable "on_demand_base_capacity" {
  description = "On-demand base capacity"
  type        = number
  default     = 0
}

variable "on_demand_percentage_above_base_capacity" {
  description = "On-demand percentage above base capacity"
  type        = number
  default     = 25
}

variable "spot_allocation_strategy" {
  description = "Spot allocation strategy"
  type        = string
  default     = "capacity-optimized"
}

variable "spot_instance_pools" {
  description = "Number of spot instance pools"
  type        = number
  default     = 2
}

variable "spot_max_price" {
  description = "Maximum price for spot instances"
  type        = string
  default     = null
}

# Instance Requirements (for mixed instance types)
variable "instance_requirements" {
  description = "Instance requirements for mixed instance types"
  type = object({
    memory_mib_min       = number
    memory_mib_max       = number
    vcpu_count_min       = number
    vcpu_count_max       = number
    instance_generations = list(string)
  })
  default = {
    memory_mib_min       = 1024
    memory_mib_max       = 8192
    vcpu_count_min       = 1
    vcpu_count_max       = 4
    instance_generations = ["current"]
  }
}

# Instance Refresh
variable "instance_refresh" {
  description = "Instance refresh configuration"
  type = object({
    strategy               = string
    instance_warmup        = number
    min_healthy_percentage = number
    triggers               = list(string)
  })
  default = null
}

# Warm Pool
variable "warm_pool" {
  description = "Warm pool configuration"
  type = object({
    pool_state                  = string
    min_size                   = number
    max_group_prepared_capacity = number
  })
  default = null
}

# Auto Scaling Policies
variable "enable_scaling_policies" {
  description = "Whether to enable auto scaling policies"
  type        = bool
  default     = false
}

variable "scale_up_adjustment" {
  description = "Number of instances to scale up"
  type        = number
  default     = 1
}

variable "scale_up_adjustment_type" {
  description = "Scale up adjustment type"
  type        = string
  default     = "ChangeInCapacity"
}

variable "scale_up_cooldown" {
  description = "Scale up cooldown period"
  type        = number
  default     = 300
}

variable "scale_down_adjustment" {
  description = "Number of instances to scale down"
  type        = number
  default     = -1
}

variable "scale_down_adjustment_type" {
  description = "Scale down adjustment type"
  type        = string
  default     = "ChangeInCapacity"
}

variable "scale_down_cooldown" {
  description = "Scale down cooldown period"
  type        = number
  default     = 300
}

# CloudWatch Alarms
variable "cpu_high_threshold" {
  description = "CPU high threshold for scaling up"
  type        = number
  default     = 80
}

variable "cpu_high_evaluation_periods" {
  description = "CPU high evaluation periods"
  type        = number
  default     = 2
}

variable "cpu_high_period" {
  description = "CPU high period"
  type        = number
  default     = 120
}

variable "cpu_low_threshold" {
  description = "CPU low threshold for scaling down"
  type        = number
  default     = 10
}

variable "cpu_low_evaluation_periods" {
  description = "CPU low evaluation periods"
  type        = number
  default     = 2
}

variable "cpu_low_period" {
  description = "CPU low period"
  type        = number
  default     = 120
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "propagate_tags_at_launch" {
  description = "Whether to propagate tags at launch"
  type        = bool
  default     = true
}
