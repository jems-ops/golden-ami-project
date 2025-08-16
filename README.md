# Golden AMI Project

A comprehensive DevOps solution for creating standardized, security-hardened Amazon Machine Images (AMIs) using Packer and Ansible.

## 🎯 Overview

This project provides infrastructure-as-code for building golden AMIs that serve as standardized, pre-configured base images for EC2 instances. The golden AMIs include security hardening, monitoring agents, essential tools, and compliance configurations.

## 📁 Project Structure

```
golden-ami-project/
├── packer/                    # Packer templates and configurations
│   ├── golden-ami.pkr.hcl     # Main Packer template
│   └── variables.pkrvars.hcl  # Packer variables
├── ansible/                   # Ansible playbooks and roles
│   ├── playbooks/
│   │   └── golden-ami.yml     # Main configuration playbook
│   ├── roles/                 # Custom Ansible roles (future use)
│   └── inventory/
│       └── hosts              # Ansible inventory
├── terraform/                 # Terraform modules and examples
│   ├── modules/
│   │   ├── golden-ami-data/   # AMI data source module
│   │   ├── ec2-instance/      # EC2 instance deployment module
│   │   └── asg-launch-template/ # Auto Scaling Group module
│   └── examples/
│       ├── single-instance/   # Single EC2 instance example
│       ├── auto-scaling/      # Auto Scaling Group example
│       └── multi-az-deployment/ # Multi-AZ deployment example
├── scripts/                   # Build and automation scripts
│   ├── build-ami.sh           # Main AMI build script
│   └── validate-ami.sh        # AMI validation script
├── policies/                  # AWS IAM policies and CloudFormation
│   ├── packer-ami-builder-policy.json
│   └── iam-roles.yml          # CloudFormation template
├── .github/workflows/         # CI/CD pipeline configurations
├── docs/                      # Additional documentation
└── README.md                  # This file
```

## 🚀 Features

### Security Hardening
- SSH hardening (disable root login, password auth)
- UFW firewall configuration
- Fail2ban intrusion prevention
- System updates and security patches

### Monitoring & Logging
- CloudWatch agent pre-configured
- System logs forwarding to CloudWatch
- Performance metrics collection
- Custom monitoring scripts

### Essential Tools
- Docker and Docker Compose
- AWS CLI
- Development tools (git, vim, htop, etc.)
- Python environment with pip

### System Configuration
- UTC timezone setting
- NTP time synchronization
- Optimized system settings
- Build metadata tracking

## 📋 Prerequisites

Before using this project, ensure you have:

### Required Software
- [Packer](https://www.packer.io/downloads) (>= 1.8.0)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) (>= 2.9)
- [AWS CLI](https://aws.amazon.com/cli/) (>= 2.0)
- jq (for JSON processing)

### AWS Setup
1. AWS account with appropriate permissions
2. AWS CLI configured with credentials
3. IAM role/policy for Packer (see [IAM Setup](#iam-setup))

### Installation Commands
```bash
# macOS
brew install packer ansible awscli jq

# Ubuntu/Debian
sudo apt update
sudo apt install -y packer ansible awscli jq

# CentOS/RHEL
sudo yum install -y packer ansible awscli jq
```

## 🔧 IAM Setup

### Option 1: Use CloudFormation Template
Deploy the IAM roles and policies using the provided CloudFormation template:

```bash
aws cloudformation create-stack \
  --stack-name packer-iam-roles \
  --template-body file://policies/iam-roles.yml \
  --capabilities CAPABILITY_NAMED_IAM
```

### Option 2: Create IAM Policy Manually
1. Create an IAM policy using `policies/packer-ami-builder-policy.json`
2. Create an IAM role and attach the policy
3. Add the role ARN to your AWS credentials or instance profile

## 🛠️ Usage

### Quick Start

1. **Clone and navigate to the project:**
   ```bash
   git clone <repository-url>
   cd golden-ami-project
   ```

2. **Configure AWS credentials:**
   ```bash
   aws configure
   ```

3. **Build your first golden AMI:**
   ```bash
   ./scripts/build-ami.sh
   ```

### Detailed Usage

#### Build AMI with Custom Parameters
```bash
# Build for specific environment and region
./scripts/build-ami.sh production us-west-2

# Build for development environment
./scripts/build-ami.sh development us-east-1
```

#### Validate an Existing AMI
```bash
./scripts/validate-ami.sh ami-1234567890abcdef0 us-west-2
```

#### Manual Packer Build
```bash
cd packer
packer validate golden-ami.pkr.hcl
packer build golden-ami.pkr.hcl
```

## 🔧 Configuration

### Packer Variables
Modify `packer/variables.pkrvars.hcl` to customize your build:

```hcl
aws_region = "us-west-2"
instance_type = "t3.medium"
environment = "production"
ami_name_prefix = "golden-ami-ubuntu-22.04"
```

### Ansible Configuration
Customize the system configuration by editing `ansible/playbooks/golden-ami.yml`:

- Add/remove packages
- Modify security settings
- Configure monitoring
- Add custom scripts

### Environment-Specific Builds
Create environment-specific variable files:

```bash
# Create production variables
cp packer/variables.pkrvars.hcl packer/prod-variables.pkrvars.hcl

# Use with Packer
packer build -var-file="prod-variables.pkrvars.hcl" golden-ami.pkr.hcl
```

## 📊 Monitoring and Validation

### Build Logs
All build activities are logged in the `logs/` directory:
- `build-YYYYMMDD-HHMMSS.log` - Detailed build logs
- `last-build-{environment}.json` - Latest build metadata

### AMI Validation
The validation script performs comprehensive checks:
- AMI availability and state
- Tag validation
- Permission verification
- Optional test instance launch

### Build Artifacts
After each build, you'll find:
- `manifest.json` - Packer build manifest
- Build metadata in logs directory
- AMI ID and details in AWS console

## 🔄 CI/CD Integration

### GitHub Actions
A GitHub Actions workflow is provided for automated builds:

```yaml
# Trigger on push to main branch
on:
  push:
    branches: [ main ]
  schedule:
    - cron: '0 2 * * 0'  # Weekly builds
```

### Jenkins Integration
For Jenkins users, create a pipeline job that:
1. Checks out the repository
2. Runs `./scripts/build-ami.sh`
3. Archives build artifacts
4. Triggers downstream deployments

## 🛡️ Security Considerations

### IAM Permissions
- Use least privilege principle
- Regularly review and audit permissions
- Consider using cross-account roles for production

### Secrets Management
- Never hardcode credentials in templates
- Use AWS Systems Manager Parameter Store
- Implement secret rotation policies

### AMI Security
- Regularly update base AMIs
- Scan for vulnerabilities
- Implement AMI lifecycle policies

## 🔍 Troubleshooting

### Common Issues

#### Packer Build Failures
```bash
# Validate template first
packer validate golden-ami.pkr.hcl

# Check AWS credentials
aws sts get-caller-identity

# Review build logs
tail -f logs/build-*.log
```

#### Ansible Failures
```bash
# Test Ansible connectivity
ansible all -m ping -i ansible/inventory/hosts

# Run playbook in check mode
ansible-playbook --check ansible/playbooks/golden-ami.yml
```

#### Permission Issues
- Verify IAM policies are attached
- Check resource limits (EC2, EBS quotas)
- Ensure region-specific permissions

### Debug Mode
Enable debug mode for detailed troubleshooting:

```bash
# Packer debug mode
PACKER_LOG=1 packer build golden-ami.pkr.hcl

# Ansible verbose mode
ansible-playbook -vvv ansible/playbooks/golden-ami.yml
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Development Guidelines
- Follow existing code style
- Update documentation
- Test changes thoroughly
- Use semantic commit messages

## 📜 License

This project is licensed under the MIT License. See the LICENSE file for details.

## 📞 Support

For support and questions:
- Create an issue in the repository
- Check the troubleshooting section
- Review AWS Packer documentation

## 🏗️ Terraform Integration

This project includes comprehensive Terraform modules for deploying infrastructure using the Golden AMIs:

### Available Modules

- **golden-ami-data**: Automatically finds the latest Golden AMI
- **ec2-instance**: Deploys single or multiple EC2 instances
- **asg-launch-template**: Creates Auto Scaling Groups with Launch Templates

### Quick Start with Terraform

1. **Deploy a single instance:**
   ```bash
   cd terraform/examples/single-instance
   terraform init
   terraform apply
   ```

2. **Deploy an Auto Scaling Group:**
   ```bash
   cd terraform/examples/auto-scaling
   terraform init
   terraform apply
   ```

### Module Usage

```hcl
module "web_servers" {
  source = "./terraform/modules/ec2-instance"

  name               = "web-servers"
  instance_type      = "t3.medium"
  instance_count     = 3
  environment        = "production"
  
  # Golden AMI will be automatically selected
  ami_name_pattern   = "golden-ami-ubuntu-22.04-*"
  
  # Security and access
  enable_http        = true
  enable_https       = true
  create_iam_role    = true
  
  tags = {
    Project = "MyApp"
    Environment = "production"
  }
}
```

## 🗺️ Roadmap

- [x] Terraform integration for AMI deployment
- [ ] Support for additional operating systems (CentOS, Amazon Linux)
- [ ] Integration with AWS Config for compliance
- [ ] Automated vulnerability scanning
- [ ] Multi-region AMI distribution
- [ ] Custom Ansible roles library

## 📚 Additional Resources

- [AWS Packer Builder Documentation](https://www.packer.io/plugins/builders/amazon)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [AWS AMI Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
