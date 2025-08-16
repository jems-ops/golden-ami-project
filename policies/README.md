# IAM Roles and Policies for Golden AMI Building

This directory contains both **CloudFormation** and **Terraform** configurations for creating the necessary IAM roles and policies for Packer to build Golden AMIs.

## 📋 Available Options

### Option 1: CloudFormation Template
- **File**: `iam-roles.yml`
- **Best for**: Teams already using CloudFormation
- **Features**: Basic IAM role and policy creation

### Option 2: Terraform Configuration
- **Files**: `iam-roles.tf`, `variables.tf`, `outputs.tf`
- **Best for**: Teams using Terraform or wanting more flexibility
- **Features**: Advanced configuration options, cross-account access, IAM users, SSM integration

## 🚀 Quick Start

### Using CloudFormation

```bash
# Deploy the IAM roles and policies
aws cloudformation create-stack \
  --stack-name packer-iam-roles \
  --template-body file://iam-roles.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### Using Terraform

```bash
# 1. Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# 2. Edit terraform.tfvars with your preferences
# nano terraform.tfvars

# 3. Initialize Terraform
terraform init

# 4. Review the plan
terraform plan

# 5. Apply the configuration
terraform apply
```

## 🔧 Terraform Configuration Options

The Terraform configuration provides extensive customization options:

### Basic Configuration
```hcl
# terraform.tfvars
aws_region = "us-east-1"
role_name  = "MyPackerRole"
policy_name = "MyPackerPolicy"

tags = {
  Project = "MyProject"
  Team    = "DevOps"
}
```

### Cross-Account Access
```hcl
# Allow other AWS accounts to assume the role
trusted_account_ids = ["123456789012", "987654321098"]
external_id = "my-secure-external-id"
```

### IAM User Creation (Alternative to Role)
```hcl
# Create an IAM user with programmatic access
create_iam_user   = true
create_access_key = true
store_keys_in_ssm = true  # Store keys securely in Parameter Store
```

### Additional Permissions
```hcl
# Enable additional services
enable_cloudwatch_logs = true
enable_ssm_access     = true

# Attach additional managed policies
additional_managed_policies = [
  "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
]

# Add custom policy statements
additional_policy_statements = [
  {
    sid       = "CustomS3Access"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["arn:aws:s3:::my-packer-bucket/*"]
    conditions = []
  }
]
```

## 🔍 What Gets Created

### Core Resources (Both Options)
- **IAM Role**: For EC2 instances and cross-account access
- **IAM Policy**: With all necessary Packer permissions
- **Instance Profile**: For EC2 instances to assume the role

### Terraform Additional Resources (Optional)
- **IAM User**: For programmatic access (alternative to role assumption)
- **Access Keys**: For the IAM user
- **SSM Parameters**: Secure storage for access keys
- **Cross-Account Trust**: For multi-account setups

## 🛡️ Security Features

### Least Privilege Access
The policies follow the principle of least privilege, granting only the minimum permissions required for Packer to build AMIs.

### Secure Key Management
When using the Terraform option with IAM users:
- Access keys can be stored in AWS Systems Manager Parameter Store
- Secret keys are encrypted using AWS managed KMS keys
- Keys are marked as sensitive in Terraform state

### Cross-Account Security
- External ID requirement for cross-account access
- Configurable trusted account list
- Session duration limits

## 📊 Permissions Included

The IAM policy includes permissions for:

### EC2 Operations
- Launch and terminate instances
- Create and manage AMIs
- Create and manage snapshots
- Manage security groups (temporary)
- Manage key pairs (temporary)
- Tag resources

### Storage Operations
- Create and manage EBS volumes
- KMS encryption/decryption for encrypted volumes

### Optional Services
- CloudWatch Logs (for build logging)
- Systems Manager Parameter Store (for configuration)

## 🔄 Usage with Packer

### Using IAM Role (Recommended)
```bash
# Set up AWS profile with role assumption
aws configure set role_arn arn:aws:iam::ACCOUNT:role/PackerAMIBuilderRole
aws configure set source_profile default
aws configure set external_id packer-build

# Run Packer
packer build golden-ami.pkr.hcl
```

### Using IAM User
```bash
# Set environment variables (if using IAM user)
export AWS_ACCESS_KEY_ID=$(aws ssm get-parameter --name /packer/aws_access_key_id --query Parameter.Value --output text)
export AWS_SECRET_ACCESS_KEY=$(aws ssm get-parameter --name /packer/aws_secret_access_key --with-decryption --query Parameter.Value --output text)

# Run Packer
packer build golden-ami.pkr.hcl
```

## 🧹 Cleanup

### CloudFormation
```bash
aws cloudformation delete-stack --stack-name packer-iam-roles
```

### Terraform
```bash
terraform destroy
```

## 📝 Customization Examples

### Enterprise Setup with Cross-Account Access
```hcl
# terraform.tfvars for enterprise setup
role_name = "EnterprisePacker"
iam_path = "/packer/"

trusted_account_ids = [
  "111111111111",  # Development Account
  "222222222222",  # Staging Account  
  "333333333333"   # Production Account
]
external_id = "enterprise-packer-2024"

enable_cloudwatch_logs = true
enable_ssm_access = true

additional_managed_policies = [
  "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
]

tags = {
  Project      = "Golden AMI Enterprise"
  Department   = "Platform Engineering"
  CostCenter   = "12345"
  Environment  = "shared"
}
```

### Development Setup with IAM User
```hcl
# terraform.tfvars for development setup
role_name = "DevPacker"

create_iam_user   = true
create_access_key = true
store_keys_in_ssm = true

enable_cloudwatch_logs = true
enable_ssm_access = true

tags = {
  Project     = "Golden AMI Dev"
  Team        = "DevOps"
  Environment = "development"
}
```

## ⚠️ Important Notes

1. **Choose One Option**: Use either CloudFormation OR Terraform, not both
2. **Secure Credentials**: Never commit access keys to version control
3. **Regular Rotation**: Rotate access keys regularly if using IAM users
4. **Monitor Usage**: Use AWS CloudTrail to monitor role/user usage
5. **Test Permissions**: Validate permissions in a non-production environment first

## 🔗 Integration with Makefile

The project Makefile includes commands for both options:

```bash
# Using CloudFormation (existing command)
make setup-iam

# Using Terraform (add to your workflow)
cd policies && terraform apply
```
