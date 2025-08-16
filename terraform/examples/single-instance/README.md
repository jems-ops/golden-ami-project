# Single EC2 Instance Example

This example demonstrates how to deploy a single EC2 instance using the latest Golden AMI.

## Features

- **Golden AMI Integration**: Automatically finds and uses the latest Golden AMI
- **Security**: Creates security groups with configurable access rules
- **IAM Integration**: Creates IAM roles with CloudWatch and SSM permissions
- **Storage**: Configurable root volume and optional additional data volumes
- **Monitoring**: Optional detailed monitoring and CloudWatch integration
- **Load Balancer**: Optional Application Load Balancer for high availability
- **Elastic IP**: Optional static IP assignment

## Quick Start

1. **Prerequisites**:
   - AWS CLI configured
   - Terraform >= 1.0 installed
   - A Golden AMI built using the Packer templates in this repository

2. **Deploy the infrastructure**:
   ```bash
   cd terraform/examples/single-instance
   
   # Initialize Terraform
   terraform init
   
   # Review the plan
   terraform plan
   
   # Apply the configuration
   terraform apply
   ```

3. **Access your instance**:
   ```bash
   # Get the connection info
   terraform output ssh_connection
   terraform output web_url
   
   # SSH to the instance (if key_name is provided)
   ssh -i ~/.ssh/your-key.pem ubuntu@<instance-ip>
   ```

## Configuration

### Required Variables

- `aws_region`: AWS region to deploy in (default: us-east-1)
- `instance_name`: Name for the EC2 instance

### Optional Variables

- `instance_type`: EC2 instance type (default: t3.medium)
- `key_name`: EC2 key pair for SSH access
- `enable_http`: Enable HTTP access (default: true)
- `enable_https`: Enable HTTPS access (default: true)
- `create_elastic_ip`: Create an Elastic IP (default: false)
- `create_load_balancer`: Create an Application Load Balancer (default: false)

### Example terraform.tfvars

```hcl
# Basic configuration
instance_name = "my-golden-ami-instance"
environment   = "development"
aws_region    = "us-east-1"

# Instance configuration
instance_type = "t3.medium"
key_name      = "my-ec2-key"

# Networking
associate_public_ip_address = true
ssh_cidr_blocks            = ["10.0.0.0/8"]  # Restrict SSH access

# Storage
root_volume_size   = 20
create_data_volume = true
data_volume_size   = 100

# Optional features
create_elastic_ip     = true
create_load_balancer = false
detailed_monitoring   = false

# Tags
common_tags = {
  Project     = "My Application"
  Environment = "development"
  Owner       = "DevOps Team"
}
```

## Outputs

- `instance_id`: EC2 instance ID
- `instance_public_ip`: Public IP address
- `instance_private_ip`: Private IP address
- `ami_id`: ID of the Golden AMI used
- `security_group_id`: Security group ID
- `ssh_connection`: SSH connection command
- `web_url`: URL to access the web application

## Customization

### User Data

The example includes a default user data script that installs and configures nginx. You can customize this by modifying the `user_data` variable:

```hcl
user_data = <<-EOF
  #!/bin/bash
  # Your custom initialization script
  apt-get update -y
  apt-get install -y your-application
  # Configure your application
EOF
```

### Security Groups

Add custom ingress rules using the security group module's flexibility:

```hcl
# In the module call
custom_ingress_rules = [
  {
    description = "Custom Application Port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
]
```

### Additional Storage

Configure additional EBS volumes:

```hcl
create_data_volume = true
data_volume_size   = 500  # GB
```

## Cost Considerations

- **Instance Type**: Choose appropriate instance types for your workload
- **Storage**: gp3 volumes offer better price-performance than gp2
- **Elastic IP**: Charged when not associated with a running instance
- **Load Balancer**: ALB has hourly charges plus per-LCU pricing

## Security Best Practices

1. **SSH Access**: Restrict SSH CIDR blocks to known networks
2. **Security Groups**: Follow principle of least privilege
3. **IAM Roles**: Use instance profiles instead of hardcoded credentials
4. **Encryption**: Root volumes are encrypted by default
5. **Monitoring**: Enable CloudWatch detailed monitoring for production

## Troubleshooting

### Common Issues

1. **AMI Not Found**: Ensure you have built a Golden AMI first
2. **Key Pair Issues**: Verify the key pair exists in the target region
3. **VPC Issues**: If using custom VPC, ensure subnets exist in specified AZs
4. **Security Groups**: Check that security group rules allow required access

### Debug Commands

```bash
# Check if AMI exists
aws ec2 describe-images --owners self --filters "Name=name,Values=golden-ami-ubuntu-22.04-*"

# Check instance status
aws ec2 describe-instances --instance-ids <instance-id>

# View instance logs
aws logs get-log-events --log-group-name /aws/ec2/user-data --log-stream-name <instance-id>
```

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

**Note**: This will permanently delete all resources created by this example.
