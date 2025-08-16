# Variables for Terraform IAM roles and policies configuration

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

# IAM Role and Policy Configuration
variable "role_name" {
  description = "Name for the Packer IAM role (if null, uses default naming)"
  type        = string
  default     = null
}

variable "policy_name" {
  description = "Name for the Packer IAM policy (if null, uses default naming)"
  type        = string
  default     = null
}

variable "iam_path" {
  description = "Path for IAM resources"
  type        = string
  default     = "/"
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds for the role"
  type        = number
  default     = 3600
  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Max session duration must be between 1 hour (3600) and 12 hours (43200)."
  }
}

# Cross-account access
variable "trusted_account_ids" {
  description = "List of AWS account IDs that can assume the role"
  type        = list(string)
  default     = []
}

variable "allow_current_account_assume" {
  description = "Allow the current AWS account root to assume the role"
  type        = bool
  default     = true
}

variable "external_id" {
  description = "External ID for cross-account access (required if trusted_account_ids is not empty)"
  type        = string
  default     = "packer-build"
}

# KMS Configuration
variable "kms_key_arns" {
  description = "List of KMS key ARNs that Packer can use for encryption (use ['*'] for all keys)"
  type        = list(string)
  default     = ["*"]
}

# Additional Permissions
variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs permissions for Packer"
  type        = bool
  default     = true
}

variable "enable_ssm_access" {
  description = "Enable Systems Manager Parameter Store access for Packer"
  type        = bool
  default     = true
}

variable "additional_managed_policies" {
  description = "List of additional managed policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

# Custom Policy Statements
variable "additional_policy_statements" {
  description = "Additional custom policy statements to add to the Packer policy"
  type = list(object({
    sid       = string
    effect    = string
    actions   = list(string)
    resources = list(string)
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })))
  }))
  default = []
}

# Instance Profile
variable "create_instance_profile" {
  description = "Whether to create an instance profile for the role"
  type        = bool
  default     = true
}

# IAM User for programmatic access (alternative to role)
variable "create_iam_user" {
  description = "Create an IAM user with the same permissions (for programmatic access)"
  type        = bool
  default     = false
}

variable "create_access_key" {
  description = "Create access keys for the IAM user (only if create_iam_user is true)"
  type        = bool
  default     = false
}

variable "store_keys_in_ssm" {
  description = "Store access keys in Systems Manager Parameter Store (only if create_access_key is true)"
  type        = bool
  default     = false
}

# Tags
variable "tags" {
  description = "Tags to apply to all created resources"
  type        = map(string)
  default = {
    Project     = "Golden AMI"
    Environment = "shared"
  }
}
