variable "ami_name_pattern" {
  description = "Pattern to match AMI names (supports wildcards)"
  type        = string
  default     = "golden-ami-ubuntu-22.04-*"
}

variable "ami_owners" {
  description = "List of AMI owners to search within"
  type        = list(string)
  default     = ["self"]
}

variable "environment" {
  description = "Environment tag to filter by (optional)"
  type        = string
  default     = null
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

variable "tags" {
  description = "Tags to apply to resources created by this module"
  type        = map(string)
  default     = {}
}
