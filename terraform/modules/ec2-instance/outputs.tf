# Golden AMI outputs
output "ami_id" {
  description = "ID of the Golden AMI used"
  value       = module.golden_ami.ami_id
}

output "ami_name" {
  description = "Name of the Golden AMI used"
  value       = module.golden_ami.ami_name
}

# Instance outputs
output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = aws_instance.ec2[*].id
}

output "instance_arns" {
  description = "List of EC2 instance ARNs"
  value       = aws_instance.ec2[*].arn
}

output "instance_public_ips" {
  description = "List of public IP addresses of instances"
  value       = aws_instance.ec2[*].public_ip
}

output "instance_private_ips" {
  description = "List of private IP addresses of instances"
  value       = aws_instance.ec2[*].private_ip
}

output "instance_public_dns" {
  description = "List of public DNS names of instances"
  value       = aws_instance.ec2[*].public_dns
}

output "instance_private_dns" {
  description = "List of private DNS names of instances"
  value       = aws_instance.ec2[*].private_dns
}

output "instance_availability_zones" {
  description = "List of availability zones of instances"
  value       = aws_instance.ec2[*].availability_zone
}

output "instance_subnet_ids" {
  description = "List of subnet IDs where instances are launched"
  value       = aws_instance.ec2[*].subnet_id
}

# Security Group outputs
output "security_group_id" {
  description = "ID of the security group (if created)"
  value       = var.create_security_group ? aws_security_group.ec2[0].id : null
}

output "security_group_arn" {
  description = "ARN of the security group (if created)"
  value       = var.create_security_group ? aws_security_group.ec2[0].arn : null
}

# IAM outputs
output "iam_role_arn" {
  description = "ARN of the IAM role (if created)"
  value       = var.create_iam_role ? aws_iam_role.ec2[0].arn : null
}

output "iam_role_name" {
  description = "Name of the IAM role (if created)"
  value       = var.create_iam_role ? aws_iam_role.ec2[0].name : null
}

output "iam_instance_profile_arn" {
  description = "ARN of the instance profile (if created)"
  value       = var.create_iam_role ? aws_iam_instance_profile.ec2[0].arn : null
}

output "iam_instance_profile_name" {
  description = "Name of the instance profile (if created)"
  value       = var.create_iam_role ? aws_iam_instance_profile.ec2[0].name : null
}

# Key Pair outputs
output "key_pair_name" {
  description = "Name of the key pair (if created)"
  value       = var.create_key_pair && var.public_key != null ? aws_key_pair.ec2[0].key_name : null
}

output "key_pair_fingerprint" {
  description = "Fingerprint of the key pair (if created)"
  value       = var.create_key_pair && var.public_key != null ? aws_key_pair.ec2[0].fingerprint : null
}

# Elastic IP outputs
output "elastic_ips" {
  description = "List of Elastic IP addresses (if created)"
  value       = var.create_elastic_ips ? aws_eip.ec2[*].public_ip : []
}

output "elastic_ip_allocation_ids" {
  description = "List of Elastic IP allocation IDs (if created)"
  value       = var.create_elastic_ips ? aws_eip.ec2[*].allocation_id : []
}

# VPC and network outputs
output "vpc_id" {
  description = "ID of the VPC where instances are launched"
  value       = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id
}

output "subnet_ids" {
  description = "List of subnet IDs where instances can be launched"
  value       = data.aws_subnets.selected.ids
}
