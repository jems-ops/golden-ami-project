# Instance outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.golden_ami_instance.instance_ids[0]
}

output "instance_public_ip" {
  description = "Public IP address of the instance"
  value       = module.golden_ami_instance.instance_public_ips[0]
}

output "instance_private_ip" {
  description = "Private IP address of the instance"
  value       = module.golden_ami_instance.instance_private_ips[0]
}

output "instance_public_dns" {
  description = "Public DNS name of the instance"
  value       = module.golden_ami_instance.instance_public_dns[0]
}

output "instance_private_dns" {
  description = "Private DNS name of the instance"
  value       = module.golden_ami_instance.instance_private_dns[0]
}

output "ami_id" {
  description = "ID of the Golden AMI used"
  value       = module.golden_ami_instance.ami_id
}

output "ami_name" {
  description = "Name of the Golden AMI used"
  value       = module.golden_ami_instance.ami_name
}

# Security Group outputs
output "security_group_id" {
  description = "ID of the security group"
  value       = module.golden_ami_instance.security_group_id
}

# IAM outputs
output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = module.golden_ami_instance.iam_role_arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = module.golden_ami_instance.iam_instance_profile_name
}

# Load Balancer outputs (if created)
output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = var.create_load_balancer ? aws_lb.app[0].dns_name : null
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = var.create_load_balancer ? aws_lb.app[0].zone_id : null
}

# Elastic IP outputs (if created)
output "elastic_ip" {
  description = "Elastic IP address (if created)"
  value       = var.create_elastic_ip ? module.golden_ami_instance.elastic_ips[0] : null
}

# Connection information
output "ssh_connection" {
  description = "SSH connection command"
  value = var.key_name != null ? (
    var.create_elastic_ip ? 
    "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.golden_ami_instance.elastic_ips[0]}" :
    "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.golden_ami_instance.instance_public_ips[0]}"
  ) : "No key pair specified"
}

output "web_url" {
  description = "Web URL to access the application"
  value = var.create_load_balancer ? (
    "http://${aws_lb.app[0].dns_name}"
  ) : (
    var.create_elastic_ip ? 
    "http://${module.golden_ami_instance.elastic_ips[0]}" :
    "http://${module.golden_ami_instance.instance_public_ips[0]}"
  )
}
