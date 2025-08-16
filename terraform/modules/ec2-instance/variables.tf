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

# Instance configuration
variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 1
}

# Networking
variable "vpc_id" {
  description = "VPC ID to launch instances in (uses default VPC if not specified)"
  type        = string
  default     = null
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
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

# Key Pair
variable "key_name" {
  description = "Existing key pair name (used if create_key_pair is false)"
  type        = string
  default     = null
}

variable "create_key_pair" {
  description = "Whether to create a key pair"
  type        = bool
  default     = false
}

variable "public_key" {
  description = "Public key for SSH access"
  type        = string
  default     = null
}

# Storage
variable "root_volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp3"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "root_volume_encrypted" {
  description = "Whether to encrypt the root volume"
  type        = bool
  default     = true
}

variable "root_delete_on_termination" {
  description = "Whether to delete root volume on termination"
  type        = bool
  default     = true
}

variable "ebs_block_devices" {
  description = "List of additional EBS block devices"
  type = list(object({
    device_name           = string
    volume_type           = string
    volume_size           = number
    encrypted             = bool
    delete_on_termination = bool
  }))
  default = []
}

# User Data
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

variable "user_data_replace_on_change" {
  description = "Whether to replace instance when user data changes"
  type        = bool
  default     = false
}

# Monitoring and other settings
variable "detailed_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}

variable "disable_api_termination" {
  description = "Disable API termination"
  type        = bool
  default     = false
}

variable "instance_initiated_shutdown_behavior" {
  description = "Instance initiated shutdown behavior"
  type        = string
  default     = "stop"
}

# Elastic IPs
variable "create_elastic_ips" {
  description = "Whether to create Elastic IPs for instances"
  type        = bool
  default     = false
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
