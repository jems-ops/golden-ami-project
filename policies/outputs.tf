# Outputs for Terraform IAM roles and policies configuration

# IAM Role outputs
output "packer_role_arn" {
  description = "ARN of the Packer IAM role"
  value       = aws_iam_role.packer_role.arn
}

output "packer_role_name" {
  description = "Name of the Packer IAM role"
  value       = aws_iam_role.packer_role.name
}

output "packer_role_unique_id" {
  description = "Unique ID of the Packer IAM role"
  value       = aws_iam_role.packer_role.unique_id
}

# IAM Policy outputs
output "packer_policy_arn" {
  description = "ARN of the Packer IAM policy"
  value       = aws_iam_policy.packer_policy.arn
}

output "packer_policy_name" {
  description = "Name of the Packer IAM policy"
  value       = aws_iam_policy.packer_policy.name
}

output "packer_policy_id" {
  description = "ID of the Packer IAM policy"
  value       = aws_iam_policy.packer_policy.id
}

# Instance Profile outputs
output "packer_instance_profile_arn" {
  description = "ARN of the Packer instance profile (if created)"
  value       = var.create_instance_profile ? aws_iam_instance_profile.packer_instance_profile[0].arn : null
}

output "packer_instance_profile_name" {
  description = "Name of the Packer instance profile (if created)"
  value       = var.create_instance_profile ? aws_iam_instance_profile.packer_instance_profile[0].name : null
}

# IAM User outputs (if created)
output "packer_user_arn" {
  description = "ARN of the Packer IAM user (if created)"
  value       = var.create_iam_user ? aws_iam_user.packer_user[0].arn : null
}

output "packer_user_name" {
  description = "Name of the Packer IAM user (if created)"
  value       = var.create_iam_user ? aws_iam_user.packer_user[0].name : null
}

# Access Key outputs (if created)
output "packer_access_key_id" {
  description = "Access Key ID for the Packer user (if created)"
  value       = var.create_iam_user && var.create_access_key ? aws_iam_access_key.packer_user_key[0].id : null
  sensitive   = true
}

output "packer_secret_access_key" {
  description = "Secret Access Key for the Packer user (if created)"
  value       = var.create_iam_user && var.create_access_key ? aws_iam_access_key.packer_user_key[0].secret : null
  sensitive   = true
}

# SSM Parameter outputs (if created)
output "ssm_access_key_parameter" {
  description = "SSM Parameter name for the access key (if stored in SSM)"
  value       = var.create_iam_user && var.create_access_key && var.store_keys_in_ssm ? aws_ssm_parameter.access_key_id[0].name : null
}

output "ssm_secret_key_parameter" {
  description = "SSM Parameter name for the secret key (if stored in SSM)"
  value       = var.create_iam_user && var.create_access_key && var.store_keys_in_ssm ? aws_ssm_parameter.secret_access_key[0].name : null
}

# Usage instructions
output "role_assumption_command" {
  description = "AWS CLI command to assume the Packer role"
  value = "aws sts assume-role --role-arn ${aws_iam_role.packer_role.arn} --role-session-name packer-session --external-id ${var.external_id}"
}

output "packer_environment_variables" {
  description = "Environment variables to set for Packer (when using IAM user)"
  value = var.create_iam_user && var.create_access_key ? {
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.packer_user_key[0].id
    AWS_SECRET_ACCESS_KEY = "<redacted>"
  } : null
  sensitive = true
}

# Policy JSON for reference
output "packer_policy_json" {
  description = "The IAM policy JSON document"
  value       = data.aws_iam_policy_document.packer_permissions.json
}

# Configuration summary
output "configuration_summary" {
  description = "Summary of the created IAM configuration"
  value = {
    role_created              = true
    policy_created            = true
    instance_profile_created  = var.create_instance_profile
    iam_user_created         = var.create_iam_user
    access_keys_created      = var.create_iam_user && var.create_access_key
    keys_stored_in_ssm       = var.create_iam_user && var.create_access_key && var.store_keys_in_ssm
    cloudwatch_logs_enabled  = var.enable_cloudwatch_logs
    ssm_access_enabled       = var.enable_ssm_access
    cross_account_access     = length(var.trusted_account_ids) > 0
  }
}
