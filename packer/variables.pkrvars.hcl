# Example variables file for Packer
# Copy this file and modify for different environments

aws_region = "us-east-1"
instance_type = "t3.medium"
environment = "production"
ami_name_prefix = "golden-ami-ubuntu-22.04"

# Alternative configurations:
# For development:
# environment = "development"
# instance_type = "t3.small"

# For different regions:
# aws_region = "us-east-1"
