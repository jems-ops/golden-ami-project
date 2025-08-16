# Golden AMI outputs
output "ami_id" {
  description = "ID of the Golden AMI used"
  value       = module.golden_ami.ami_id
}

output "ami_name" {
  description = "Name of the Golden AMI used"
  value       = module.golden_ami.ami_name
}

# Launch Template outputs
output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.asg.id
}

output "launch_template_arn" {
  description = "ARN of the Launch Template"
  value       = aws_launch_template.asg.arn
}

output "launch_template_name" {
  description = "Name of the Launch Template"
  value       = aws_launch_template.asg.name
}

output "launch_template_latest_version" {
  description = "Latest version of the Launch Template"
  value       = aws_launch_template.asg.latest_version
}

output "launch_template_default_version" {
  description = "Default version of the Launch Template"
  value       = aws_launch_template.asg.default_version
}

# Auto Scaling Group outputs
output "autoscaling_group_id" {
  description = "ID of the Auto Scaling Group"
  value       = aws_autoscaling_group.asg.id
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.asg.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.asg.arn
}

output "autoscaling_group_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  value       = aws_autoscaling_group.asg.min_size
}

output "autoscaling_group_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  value       = aws_autoscaling_group.asg.max_size
}

output "autoscaling_group_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  value       = aws_autoscaling_group.asg.desired_capacity
}

output "autoscaling_group_availability_zones" {
  description = "Availability zones of the Auto Scaling Group"
  value       = aws_autoscaling_group.asg.availability_zones
}

output "autoscaling_group_vpc_zone_identifier" {
  description = "VPC zone identifier of the Auto Scaling Group"
  value       = aws_autoscaling_group.asg.vpc_zone_identifier
}

output "autoscaling_group_health_check_type" {
  description = "Health check type of the Auto Scaling Group"
  value       = aws_autoscaling_group.asg.health_check_type
}

output "autoscaling_group_health_check_grace_period" {
  description = "Health check grace period of the Auto Scaling Group"
  value       = aws_autoscaling_group.asg.health_check_grace_period
}

# Security Group outputs
output "security_group_id" {
  description = "ID of the security group (if created)"
  value       = var.create_security_group ? aws_security_group.asg[0].id : null
}

output "security_group_arn" {
  description = "ARN of the security group (if created)"
  value       = var.create_security_group ? aws_security_group.asg[0].arn : null
}

output "security_group_name" {
  description = "Name of the security group (if created)"
  value       = var.create_security_group ? aws_security_group.asg[0].name : null
}

# IAM outputs
output "iam_role_arn" {
  description = "ARN of the IAM role (if created)"
  value       = var.create_iam_role ? aws_iam_role.asg[0].arn : null
}

output "iam_role_name" {
  description = "Name of the IAM role (if created)"
  value       = var.create_iam_role ? aws_iam_role.asg[0].name : null
}

output "iam_instance_profile_arn" {
  description = "ARN of the instance profile (if created)"
  value       = var.create_iam_role ? aws_iam_instance_profile.asg[0].arn : null
}

output "iam_instance_profile_name" {
  description = "Name of the instance profile (if created)"
  value       = var.create_iam_role ? aws_iam_instance_profile.asg[0].name : null
}

# Auto Scaling Policy outputs
output "scale_up_policy_arn" {
  description = "ARN of the scale up policy (if created)"
  value       = var.enable_scaling_policies ? aws_autoscaling_policy.scale_up[0].arn : null
}

output "scale_down_policy_arn" {
  description = "ARN of the scale down policy (if created)"
  value       = var.enable_scaling_policies ? aws_autoscaling_policy.scale_down[0].arn : null
}

# CloudWatch Alarm outputs
output "cpu_high_alarm_arn" {
  description = "ARN of the CPU high alarm (if created)"
  value       = var.enable_scaling_policies ? aws_cloudwatch_metric_alarm.cpu_high[0].arn : null
}

output "cpu_low_alarm_arn" {
  description = "ARN of the CPU low alarm (if created)"
  value       = var.enable_scaling_policies ? aws_cloudwatch_metric_alarm.cpu_low[0].arn : null
}

# VPC and network outputs
output "vpc_id" {
  description = "ID of the VPC where instances are launched"
  value       = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id
}

output "subnet_ids" {
  description = "List of subnet IDs where instances are launched"
  value       = var.subnet_ids != null ? var.subnet_ids : data.aws_subnets.selected.ids
}
