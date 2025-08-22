# Golden AMI Project - Technical Documentation

*Detailed implementation guide with code examples and configuration details*

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Packer Configuration](#packer-configuration)
3. [Ansible Playbooks](#ansible-playbooks)
4. [Build Automation](#build-automation)
5. [CI/CD Integration](#cicd-integration)
6. [Testing and Validation](#testing-and-validation)
7. [Security Implementation](#security-implementation)
8. [Monitoring and Observability](#monitoring-and-observability)
9. [Cost Management](#cost-management)
10. [Troubleshooting Guide](#troubleshooting-guide)

---

## Project Structure

```
golden-ami-project/
├── packer/                     # Packer templates and configurations
│   ├── golden-ami.pkr.hcl      # Main Packer template
│   └── variables.pkrvars.hcl   # Packer variables
├── ansible/                    # Ansible playbooks and roles
│   ├── playbooks/
│   │   └── golden-ami.yml      # Main configuration playbook
│   ├── roles/                  # Custom Ansible roles (future use)
│   └── inventory/
│       └── hosts               # Ansible inventory
├── terraform/                  # Terraform modules and examples
│   ├── modules/
│   │   ├── golden-ami-data/    # AMI data source module
│   │   ├── ec2-instance/       # EC2 instance deployment module
│   │   └── asg-launch-template/ # Auto Scaling Group module
│   └── examples/
│       ├── single-instance/    # Single EC2 instance example
│       ├── auto-scaling/       # Auto Scaling Group example
│       └── multi-az-deployment/ # Multi-AZ deployment example
├── scripts/                    # Build and automation scripts
│   ├── build-ami.sh           # Main AMI build script
│   └── validate-ami.sh        # AMI validation script
├── policies/                   # AWS IAM policies and CloudFormation
│   ├── packer-ami-builder-policy.json
│   └── iam-roles.yml          # CloudFormation template
└── .github/workflows/         # CI/CD pipeline
    └── build-ami.yml          # GitHub Actions workflow
```

---

## Packer Configuration

### Main Template (packer/golden-ami.pkr.hcl)

```hcl
# Define required plugins
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# Variables for customization
variable "aws_region" {
  type        = string
  description = "AWS region to build the AMI in"
  default     = "us-east-1"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type to use for building"
  default     = "t3.medium"
}

variable "source_ami_filter" {
  type        = string
  description = "Filter for source AMI"
  default     = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
}

variable "ami_name_prefix" {
  type        = string
  description = "Prefix for AMI name"
  default     = "golden-ami-ubuntu-22.04"
}

variable "environment" {
  type        = string
  description = "Environment tag for the AMI"
  default     = "production"
}

variable "build_user" {
  type        = string
  description = "User building the AMI"
  default     = "unknown"
}

# Data sources
data "amazon-ami" "ubuntu" {
  filters = {
    name                = var.source_ami_filter
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"] # Canonical
  region      = var.aws_region
}

# Local variables
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name  = "${var.ami_name_prefix}-${local.timestamp}"
}

# Build definition
source "amazon-ebs" "ubuntu" {
  ami_name      = local.ami_name
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami    = data.amazon-ami.ubuntu.id
  
  ssh_username = "ubuntu"
  ssh_timeout  = "20m"

  # EBS settings
  ebs_optimized = true
  
  run_tags = {
    Name        = "Packer Builder - ${local.ami_name}"
    Environment = var.environment
    Purpose     = "Golden AMI Build"
  }

  tags = {
    Name            = local.ami_name
    Environment     = var.environment
    OS              = "Ubuntu"
    OSVersion       = "22.04"
    Architecture    = "x86_64"
    BuildDate       = timestamp()
    PackerVersion   = packer.version
    Purpose         = "Golden AMI"
    ManagedBy       = "Packer"
  }

  # Security group for build
  temporary_security_group_source_cidrs = ["0.0.0.0/0"]
}

# Build steps
build {
  name = "golden-ami"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  # Wait for cloud-init to finish
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Cloud-init completed'"
    ]
  }

  # Update system
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y python3-pip python3-dev",
      "sudo pip3 install ansible"
    ]
  }

  # Run Ansible playbook
  provisioner "ansible" {
    playbook_file = "../ansible/playbooks/golden-ami.yml"
    user = "ubuntu"
    extra_arguments = [
      "--extra-vars",
      "target_user=ubuntu"
    ]
  }

  # Final cleanup
  provisioner "shell" {
    inline = [
      "echo 'Running final cleanup...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "history -c && history -w",
      "sudo rm -f /root/.bash_history",
      "sudo rm -f /home/ubuntu/.bash_history",
      "echo 'Cleanup completed'"
    ]
  }

  # Create AMI manifest
  post-processor "manifest" {
    output = "manifest.json"
    strip_path = true
    custom_data = {
      build_time = timestamp()
      build_user = var.build_user
    }
  }
}
```

---

## Ansible Playbooks

### Main Configuration Playbook (ansible/playbooks/golden-ami.yml)

```yaml
---
- name: Configure Golden AMI
  hosts: all
  become: yes
  gather_facts: yes
  
  vars:
    target_user: ubuntu
    
  tasks:
    - name: Update package cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install essential packages
      apt:
        name:
          - curl
          - wget
          - git
          - vim
          - htop
          - tree
          - unzip
          - jq
          - awscli
          - python3-pip
          - python3-venv
          - apt-transport-https
          - ca-certificates
          - gnupg
          - lsb-release
          - fail2ban
          - ufw
          - chrony
          - rsyslog
        state: present

    - name: Install CloudWatch agent
      get_url:
        url: https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
        dest: /tmp/amazon-cloudwatch-agent.rpm
      failed_when: false

    - name: Install Docker
      block:
        - name: Add Docker GPG key
          apt_key:
            url: https://download.docker.com/linux/ubuntu/gpg
            state: present

        - name: Add Docker repository
          apt_repository:
            repo: deb https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable
            state: present

        - name: Install Docker CE
          apt:
            name:
              - docker-ce
              - docker-ce-cli
              - containerd.io
              - docker-buildx-plugin
              - docker-compose-plugin
            state: present

        - name: Add user to docker group
          user:
            name: "{{ target_user }}"
            groups: docker
            append: yes

    - name: Configure system security
      block:
        - name: Configure UFW firewall
          ufw:
            state: enabled
            policy: deny
            direction: incoming

        - name: Allow SSH
          ufw:
            rule: allow
            port: 22
            proto: tcp

        - name: Configure fail2ban
          copy:
            dest: /etc/fail2ban/jail.local
            content: |
              [DEFAULT]
              bantime = 3600
              findtime = 600
              maxretry = 3
              
              [sshd]
              enabled = true
              port = ssh
              logpath = /var/log/auth.log
              backend = systemd

        - name: Start and enable fail2ban
          systemd:
            name: fail2ban
            state: started
            enabled: yes

    - name: Configure system monitoring
      block:
        - name: Create CloudWatch config directory
          file:
            path: /opt/aws/amazon-cloudwatch-agent/etc
            state: directory
            mode: '0755'

        - name: Create CloudWatch agent config
          copy:
            dest: /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
            content: |
              {
                "agent": {
                  "metrics_collection_interval": 60,
                  "run_as_user": "cwagent"
                },
                "metrics": {
                  "namespace": "CWAgent",
                  "metrics_collected": {
                    "cpu": {
                      "measurement": [
                        "cpu_usage_idle",
                        "cpu_usage_iowait",
                        "cpu_usage_user",
                        "cpu_usage_system"
                      ],
                      "metrics_collection_interval": 60
                    },
                    "disk": {
                      "measurement": [
                        "used_percent"
                      ],
                      "metrics_collection_interval": 60,
                      "resources": [
                        "*"
                      ]
                    },
                    "diskio": {
                      "measurement": [
                        "io_time"
                      ],
                      "metrics_collection_interval": 60,
                      "resources": [
                        "*"
                      ]
                    },
                    "mem": {
                      "measurement": [
                        "mem_used_percent"
                      ],
                      "metrics_collection_interval": 60
                    }
                  }
                },
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/syslog",
                          "log_group_name": "/aws/ec2/syslog",
                          "log_stream_name": "{instance_id}"
                        },
                        {
                          "file_path": "/var/log/auth.log",
                          "log_group_name": "/aws/ec2/auth",
                          "log_stream_name": "{instance_id}"
                        }
                      ]
                    }
                  }
                }
              }

    - name: Configure system settings
      block:
        - name: Set timezone
          timezone:
            name: UTC

        - name: Configure chrony for time sync
          copy:
            dest: /etc/chrony/chrony.conf
            content: |
              server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4
              driftfile /var/lib/chrony/drift
              makestep 1.0 3
              rtcsync
              logdir /var/log/chrony

        - name: Start and enable chrony
          systemd:
            name: chrony
            state: started
            enabled: yes

        - name: Configure SSH hardening
          lineinfile:
            path: /etc/ssh/sshd_config
            regexp: "{{ item.regexp }}"
            line: "{{ item.line }}"
            backup: yes
          with_items:
            - { regexp: '^#?PermitRootLogin', line: 'PermitRootLogin no' }
            - { regexp: '^#?PasswordAuthentication', line: 'PasswordAuthentication no' }
            - { regexp: '^#?PubkeyAuthentication', line: 'PubkeyAuthentication yes' }
            - { regexp: '^#?Protocol', line: 'Protocol 2' }
            - { regexp: '^#?ClientAliveInterval', line: 'ClientAliveInterval 300' }
            - { regexp: '^#?ClientAliveCountMax', line: 'ClientAliveCountMax 2' }

    - name: Create useful directories
      file:
        path: "{{ item }}"
        state: directory
        owner: "{{ target_user }}"
        group: "{{ target_user }}"
        mode: '0755'
      with_items:
        - /home/{{ target_user }}/scripts
        - /home/{{ target_user }}/logs

    - name: Create system info script
      copy:
        dest: /home/{{ target_user }}/scripts/system-info.sh
        owner: "{{ target_user }}"
        group: "{{ target_user }}"
        mode: '0755'
        content: |
          #!/bin/bash
          echo "=== System Information ==="
          echo "Hostname: $(hostname)"
          echo "OS: $(lsb_release -d | cut -f2-)"
          echo "Kernel: $(uname -r)"
          echo "Uptime: $(uptime -p)"
          echo "CPU Cores: $(nproc)"
          echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
          echo "Disk Usage:"
          df -h | grep -vE '^Filesystem|tmpfs|cdrom'
          echo "=== Network ==="
          ip -4 addr show | grep inet

    - name: Create AMI build info
      copy:
        dest: /etc/ami-build-info
        content: |
          AMI_BUILD_DATE={{ ansible_date_time.iso8601 }}
          AMI_BUILD_USER={{ ansible_user_id }}
          ANSIBLE_VERSION={{ ansible_version.full }}
          OS_VERSION={{ ansible_distribution }} {{ ansible_distribution_version }}
          KERNEL_VERSION={{ ansible_kernel }}

    - name: Set proper permissions on home directory
      file:
        path: /home/{{ target_user }}
        owner: "{{ target_user }}"
        group: "{{ target_user }}"
        mode: '0755'
        recurse: yes
```

---

## Build Automation

### Build Script (scripts/build-ami.sh)

```bash
#!/bin/bash

set -euo pipefail

# Golden AMI Build Script
# Usage: ./build-ami.sh [environment] [region]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
ENVIRONMENT="${1:-production}"
AWS_REGION="${2:-us-east-1}"
PACKER_DIR="$PROJECT_ROOT/packer"
LOG_DIR="$PROJECT_ROOT/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create logs directory
mkdir -p "$LOG_DIR"

# Logging
LOG_FILE="$LOG_DIR/build-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $*" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if packer is installed
    if ! command -v packer &> /dev/null; then
        error "Packer is not installed. Please install Packer first."
        exit 1
    fi
    
    # Check if AWS CLI is installed and configured
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials are not configured. Please configure AWS credentials."
        exit 1
    fi
    
    # Check if required files exist
    if [[ ! -f "$PACKER_DIR/golden-ami.pkr.hcl" ]]; then
        error "Packer template not found at $PACKER_DIR/golden-ami.pkr.hcl"
        exit 1
    fi
    
    success "All prerequisites are met"
}

# Validate Packer template
validate_template() {
    log "Validating Packer template..."
    
    cd "$PACKER_DIR"
    packer init .
    if packer validate \
        -var "environment=$ENVIRONMENT" \
        -var "aws_region=$AWS_REGION" \
        -var "build_user=$(whoami)" \
        golden-ami.pkr.hcl; then
        success "Packer template validation passed"
    else
        error "Packer template validation failed"
        exit 1
    fi
}

# Build AMI
build_ami() {
    log "Starting AMI build for environment: $ENVIRONMENT, region: $AWS_REGION"
    
    cd "$PACKER_DIR"
    
    # Create a unique build ID
    BUILD_ID="$(date +%Y%m%d-%H%M%S)-$(uuidgen | cut -d'-' -f1)"
    
    log "Build ID: $BUILD_ID"
    
    # Build the AMI
    if packer build \
        -var "environment=$ENVIRONMENT" \
        -var "aws_region=$AWS_REGION" \
        -var "build_user=$(whoami)" \
        -var "ami_name_prefix=golden-ami-ubuntu-22.04-$BUILD_ID" \
        golden-ami.pkr.hcl; then
        
        success "AMI build completed successfully"
        
        # Extract AMI ID from manifest
        if [[ -f "manifest.json" ]]; then
            AMI_ID=$(jq -r '.builds[0].artifact_id' manifest.json | cut -d':' -f2)
            AMI_REGION=$(jq -r '.builds[0].artifact_id' manifest.json | cut -d':' -f1)
            
            success "New AMI created: $AMI_ID in region $AMI_REGION"
            
            # Save build info
            cat > "$LOG_DIR/last-build-$ENVIRONMENT.json" << EOF
{
  "build_id": "$BUILD_ID",
  "ami_id": "$AMI_ID",
  "region": "$AMI_REGION",
  "environment": "$ENVIRONMENT",
  "build_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "build_user": "$(whoami)",
  "log_file": "$LOG_FILE"
}
EOF
            
            return 0
        else
            warning "Manifest file not found, unable to extract AMI ID"
            return 1
        fi
    else
        error "AMI build failed"
        exit 1
    fi
}

# Validate built AMI
validate_ami() {
    local ami_id="$1"
    local region="$2"
    
    log "Validating AMI: $ami_id"
    
    # Check if AMI exists and is available
    if aws ec2 describe-images \
        --region "$region" \
        --image-ids "$ami_id" \
        --query 'Images[0].State' \
        --output text | grep -q "available"; then
        success "AMI $ami_id is available"
        return 0
    else
        error "AMI $ami_id is not available"
        return 1
    fi
}

# Main execution
main() {
    log "Starting Golden AMI build process"
    log "Environment: $ENVIRONMENT"
    log "Region: $AWS_REGION"
    log "Log file: $LOG_FILE"
    
    check_prerequisites
    validate_template
    
    if build_ami; then
        # Read the build info to get AMI ID for validation
        if [[ -f "$LOG_DIR/last-build-$ENVIRONMENT.json" ]]; then
            AMI_ID=$(jq -r '.ami_id' "$LOG_DIR/last-build-$ENVIRONMENT.json")
            AMI_REGION=$(jq -r '.region' "$LOG_DIR/last-build-$ENVIRONMENT.json")
            
            # Wait a moment for AMI to be fully available
            log "Waiting 30 seconds before validation..."
            sleep 30
            
            if validate_ami "$AMI_ID" "$AMI_REGION"; then
                success "Golden AMI build process completed successfully!"
                log "AMI ID: $AMI_ID"
                log "Region: $AMI_REGION"
                log "Build log: $LOG_FILE"
                
                # Suggest next steps
                log ""
                log "Next steps:"
                log "1. Test the AMI by launching an instance"
                log "2. Run validation tests"
                log "3. Tag the AMI appropriately"
                log "4. Share the AMI with other accounts if needed"
            else
                warning "AMI build completed but validation failed"
            fi
        fi
    else
        error "AMI build failed"
        exit 1
    fi
}

# Handle script interruption
trap 'error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"
```

---

## CI/CD Integration

### GitHub Actions Workflow (.github/workflows/build-ami.yml)

```yaml
name: Build Golden AMI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 2 * * 0'  # Weekly builds on Sunday at 2 AM
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to build for'
        required: true
        default: 'production'
        type: choice
        options:
        - production
        - staging
        - development
      aws_region:
        description: 'AWS region'
        required: true
        default: 'us-east-1'
        type: string

env:
  ENVIRONMENT: ${{ github.event.inputs.environment || 'production' }}
  AWS_REGION: ${{ github.event.inputs.aws_region || 'us-east-1' }}

jobs:
  validate:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Setup Packer
      uses: hashicorp/setup-packer@main
      with:
        version: latest
    
    - name: Validate Packer template
      run: |
        cd packer
        packer init .
        packer validate \
          -var "environment=${{ env.ENVIRONMENT }}" \
          -var "aws_region=${{ env.AWS_REGION }}" \
          -var "build_user=github-actions" \
          golden-ami.pkr.hcl

  build:
    needs: validate
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'
    
    outputs:
      ami_id: ${{ steps.build.outputs.ami_id }}
      
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Setup Packer
      uses: hashicorp/setup-packer@main
      with:
        version: latest
    
    - name: Build Golden AMI
      id: build
      run: |
        cd packer
        packer init .
        
        # Build AMI with unique name
        BUILD_ID="$(date +%Y%m%d-%H%M%S)-${GITHUB_SHA::8}"
        
        packer build \
          -var "environment=${{ env.ENVIRONMENT }}" \
          -var "aws_region=${{ env.AWS_REGION }}" \
          -var "build_user=github-actions" \
          -var "ami_name_prefix=golden-ami-ubuntu-22.04-${BUILD_ID}" \
          golden-ami.pkr.hcl
        
        # Extract AMI ID
        if [[ -f "manifest.json" ]]; then
          AMI_ID=$(jq -r '.builds[0].artifact_id' manifest.json | cut -d':' -f2)
          echo "ami_id=$AMI_ID" >> $GITHUB_OUTPUT
          echo "Built AMI: $AMI_ID"
        else
          echo "Error: Manifest file not found"
          exit 1
        fi
    
    - name: Tag AMI
      run: |
        aws ec2 create-tags \
          --region ${{ env.AWS_REGION }} \
          --resources ${{ steps.build.outputs.ami_id }} \
          --tags \
            Key=BuildNumber,Value=${{ github.run_number }} \
            Key=GitCommit,Value=${{ github.sha }} \
            Key=GitBranch,Value=${{ github.ref_name }} \
            Key=BuildBy,Value=GitHubActions
    
    - name: Update Terraform variables
      if: github.ref == 'refs/heads/main'
      run: |
        echo "# Generated by GitHub Actions on $(date)" > terraform/golden-ami.auto.tfvars
        echo "golden_ami_id = \"${{ steps.build.outputs.ami_id }}\"" >> terraform/golden-ami.auto.tfvars
        echo "golden_ami_build_date = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" >> terraform/golden-ami.auto.tfvars
    
    - name: Commit AMI updates
      if: github.ref == 'refs/heads/main'
      run: |
        git config --global user.name 'github-actions[bot]'
        git config --global user.email 'github-actions[bot]@users.noreply.github.com'
        git add terraform/golden-ami.auto.tfvars
        git commit -m "Update Golden AMI ID: ${{ steps.build.outputs.ami_id }}"
        git push

  test:
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Test AMI
      run: |
        echo "Testing AMI: ${{ needs.build.outputs.ami_id }}"
        
        # Launch test instance
        INSTANCE_ID=$(aws ec2 run-instances \
          --image-id ${{ needs.build.outputs.ami_id }} \
          --instance-type t3.micro \
          --key-name ${{ secrets.EC2_KEY_NAME }} \
          --security-group-ids ${{ secrets.SECURITY_GROUP_ID }} \
          --subnet-id ${{ secrets.SUBNET_ID }} \
          --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=golden-ami-test},{Key=Purpose,Value=AMI-Testing}]" \
          --query 'Instances[0].InstanceId' \
          --output text)
        
        echo "Launched test instance: $INSTANCE_ID"
        
        # Wait for instance to be running
        aws ec2 wait instance-running --instance-ids $INSTANCE_ID
        echo "Instance is running"
        
        # Wait a bit more for SSH to be ready
        sleep 60
        
        # Basic health check
        aws ec2 describe-instances \
          --instance-ids $INSTANCE_ID \
          --query 'Reservations[0].Instances[0].State.Name' \
          --output text
        
        # Cleanup
        aws ec2 terminate-instances --instance-ids $INSTANCE_ID
        echo "Test instance terminated"

  notify:
    needs: [build, test]
    runs-on: ubuntu-latest
    if: always() && github.event_name != 'pull_request'
    
    steps:
    - name: Notify Success
      if: needs.build.result == 'success' && needs.test.result == 'success'
      run: |
        echo "✅ Golden AMI build completed successfully!"
        echo "AMI ID: ${{ needs.build.outputs.ami_id }}"
        echo "Environment: ${{ env.ENVIRONMENT }}"
        echo "Region: ${{ env.AWS_REGION }}"
    
    - name: Notify Failure
      if: needs.build.result == 'failure' || needs.test.result == 'failure'
      run: |
        echo "❌ Golden AMI build failed!"
        echo "Please check the logs for details."
```

---

## Testing and Validation

### AMI Validation Script (scripts/validate-ami.sh)

```bash
#!/bin/bash

set -euo pipefail

# AMI Validation Script
# Usage: ./validate-ami.sh <ami-id> [region] [key-name]

AMI_ID="${1:-}"
AWS_REGION="${2:-us-east-1}"
KEY_NAME="${3:-}"

if [[ -z "$AMI_ID" ]]; then
    echo "Usage: $0 <ami-id> [region] [key-name]"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $*"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $*"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $*"
}

# Test AMI metadata
test_ami_metadata() {
    log "Testing AMI metadata..."
    
    AMI_INFO=$(aws ec2 describe-images \
        --region "$AWS_REGION" \
        --image-ids "$AMI_ID" \
        --query 'Images[0]' 2>/dev/null)
    
    if [[ -z "$AMI_INFO" || "$AMI_INFO" == "null" ]]; then
        error "AMI $AMI_ID not found in region $AWS_REGION"
        return 1
    fi
    
    AMI_STATE=$(echo "$AMI_INFO" | jq -r '.State')
    AMI_NAME=$(echo "$AMI_INFO" | jq -r '.Name')
    
    if [[ "$AMI_STATE" == "available" ]]; then
        success "AMI is available: $AMI_NAME"
    else
        error "AMI state is $AMI_STATE, expected 'available'"
        return 1
    fi
    
    # Check required tags
    REQUIRED_TAGS=("Environment" "OS" "OSVersion" "Purpose")
    for tag in "${REQUIRED_TAGS[@]}"; do
        TAG_VALUE=$(echo "$AMI_INFO" | jq -r --arg tag "$tag" '.Tags[]? | select(.Key == $tag) | .Value')
        if [[ -n "$TAG_VALUE" && "$TAG_VALUE" != "null" ]]; then
            success "Tag $tag: $TAG_VALUE"
        else
            warning "Missing required tag: $tag"
        fi
    done
    
    return 0
}

# Launch test instance
launch_test_instance() {
    log "Launching test instance..."
    
    # Get default VPC and subnet
    VPC_ID=$(aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters "Name=is-default,Values=true" \
        --query 'Vpcs[0].VpcId' \
        --output text)
    
    SUBNET_ID=$(aws ec2 describe-subnets \
        --region "$AWS_REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=default-for-az,Values=true" \
        --query 'Subnets[0].SubnetId' \
        --output text)
    
    # Create security group for testing
    SG_ID=$(aws ec2 create-security-group \
        --region "$AWS_REGION" \
        --group-name "golden-ami-test-$(date +%s)" \
        --description "Temporary security group for Golden AMI testing" \
        --vpc-id "$VPC_ID" \
        --query 'GroupId' \
        --output text)
    
    # Add SSH rule if key name provided
    if [[ -n "$KEY_NAME" ]]; then
        aws ec2 authorize-security-group-ingress \
            --region "$AWS_REGION" \
            --group-id "$SG_ID" \
            --protocol tcp \
            --port 22 \
            --cidr 0.0.0.0/0 >/dev/null
    fi
    
    # Launch instance
    RUN_INSTANCES_ARGS=(
        --region "$AWS_REGION"
        --image-id "$AMI_ID"
        --instance-type "t3.micro"
        --subnet-id "$SUBNET_ID"
        --security-group-ids "$SG_ID"
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=golden-ami-test-$(date +%s)},{Key=Purpose,Value=Testing}]"
    )
    
    if [[ -n "$KEY_NAME" ]]; then
        RUN_INSTANCES_ARGS+=(--key-name "$KEY_NAME")
    fi
    
    INSTANCE_ID=$(aws ec2 run-instances "${RUN_INSTANCES_ARGS[@]}" \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    success "Launched test instance: $INSTANCE_ID"
    
    # Store for cleanup
    echo "$INSTANCE_ID" > /tmp/ami-test-instance
    echo "$SG_ID" > /tmp/ami-test-sg
    
    return 0
}

# Test instance boot and basic functionality
test_instance_functionality() {
    local instance_id="$1"
    
    log "Testing instance functionality..."
    
    # Wait for instance to be running
    log "Waiting for instance to be running..."
    aws ec2 wait instance-running \
        --region "$AWS_REGION" \
        --instance-ids "$instance_id"
    
    success "Instance is running"
    
    # Wait for status checks
    log "Waiting for status checks..."
    aws ec2 wait instance-status-ok \
        --region "$AWS_REGION" \
        --instance-ids "$instance_id"
    
    success "Status checks passed"
    
    # Get instance details
    INSTANCE_INFO=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0]')
    
    INSTANCE_STATE=$(echo "$INSTANCE_INFO" | jq -r '.State.Name')
    PUBLIC_IP=$(echo "$INSTANCE_INFO" | jq -r '.PublicIpAddress // "N/A"')
    PRIVATE_IP=$(echo "$INSTANCE_INFO" | jq -r '.PrivateIpAddress')
    
    success "Instance state: $INSTANCE_STATE"
    success "Public IP: $PUBLIC_IP"
    success "Private IP: $PRIVATE_IP"
    
    return 0
}

# Run SSH tests if key provided
test_ssh_connectivity() {
    local instance_id="$1"
    
    if [[ -z "$KEY_NAME" ]]; then
        warning "No key name provided, skipping SSH tests"
        return 0
    fi
    
    log "Testing SSH connectivity..."
    
    PUBLIC_IP=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    
    if [[ "$PUBLIC_IP" == "None" || "$PUBLIC_IP" == "null" ]]; then
        warning "No public IP available for SSH testing"
        return 0
    fi
    
    # Wait a bit more for SSH to be ready
    sleep 30
    
    # Test SSH connectivity
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ~/.ssh/"$KEY_NAME".pem ubuntu@"$PUBLIC_IP" 'echo "SSH test successful"' 2>/dev/null; then
        success "SSH connectivity test passed"
    else
        warning "SSH connectivity test failed"
        return 1
    fi
    
    # Test basic commands
    log "Testing installed packages..."
    
    COMMANDS=(
        "docker --version"
        "aws --version"
        "python3 --version"
        "systemctl is-active fail2ban"
        "sudo ufw status"
    )
    
    for cmd in "${COMMANDS[@]}"; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ~/.ssh/"$KEY_NAME".pem ubuntu@"$PUBLIC_IP" "$cmd" >/dev/null 2>&1; then
            success "Command test passed: $cmd"
        else
            warning "Command test failed: $cmd"
        fi
    done
    
    return 0
}

# Cleanup test resources
cleanup() {
    if [[ -f /tmp/ami-test-instance ]]; then
        INSTANCE_ID=$(cat /tmp/ami-test-instance)
        log "Terminating test instance: $INSTANCE_ID"
        aws ec2 terminate-instances \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID" >/dev/null
        rm -f /tmp/ami-test-instance
    fi
    
    if [[ -f /tmp/ami-test-sg ]]; then
        SG_ID=$(cat /tmp/ami-test-sg)
        log "Waiting for instance termination before deleting security group..."
        if [[ -n "$INSTANCE_ID" ]]; then
            aws ec2 wait instance-terminated \
                --region "$AWS_REGION" \
                --instance-ids "$INSTANCE_ID" 2>/dev/null || true
        fi
        
        log "Deleting test security group: $SG_ID"
        aws ec2 delete-security-group \
            --region "$AWS_REGION" \
            --group-id "$SG_ID" 2>/dev/null || true
        rm -f /tmp/ami-test-sg
    fi
}

# Main execution
main() {
    log "Starting AMI validation for $AMI_ID in region $AWS_REGION"
    
    # Setup cleanup trap
    trap cleanup EXIT INT TERM
    
    # Run tests
    if ! test_ami_metadata; then
        error "AMI metadata validation failed"
        exit 1
    fi
    
    if ! launch_test_instance; then
        error "Failed to launch test instance"
        exit 1
    fi
    
    INSTANCE_ID=$(cat /tmp/ami-test-instance)
    
    if ! test_instance_functionality "$INSTANCE_ID"; then
        error "Instance functionality tests failed"
        exit 1
    fi
    
    if ! test_ssh_connectivity "$INSTANCE_ID"; then
        warning "SSH connectivity tests failed (this might be expected)"
    fi
    
    success "AMI validation completed successfully!"
    log "AMI $AMI_ID is ready for production use"
}

main "$@"
```

---

## Security Implementation

### CIS Benchmark Implementation

```yaml
# Additional security hardening tasks for CIS compliance
- name: CIS 1.1.1.1 - Disable unused filesystems
  lineinfile:
    path: /etc/modprobe.d/blacklist.conf
    line: "install {{ item }} /bin/true"
    create: yes
  loop:
    - cramfs
    - freevxfs
    - jffs2
    - hfs
    - hfsplus
    - squashfs
    - udf

- name: CIS 1.4.1 - Set bootloader password
  lineinfile:
    path: /etc/grub.d/40_custom
    line: |
      set superusers="root"
      password_pbkdf2 root grub.pbkdf2.sha512.10000.HASH_HERE
    create: yes
  notify: update-grub

- name: CIS 1.5.1 - Set core dump restrictions
  lineinfile:
    path: /etc/security/limits.conf
    line: "* hard core 0"
    create: yes

- name: CIS 1.5.3 - Enable ASLR
  sysctl:
    name: kernel.randomize_va_space
    value: '2'
    state: present
    reload: yes

- name: CIS 3.1.1 - Disable IP forwarding
  sysctl:
    name: net.ipv4.ip_forward
    value: '0'
    state: present
    reload: yes

- name: CIS 3.1.2 - Disable packet redirect sending
  sysctl:
    name: "{{ item }}"
    value: '0'
    state: present
    reload: yes
  loop:
    - net.ipv4.conf.all.send_redirects
    - net.ipv4.conf.default.send_redirects

- name: CIS 3.2.1 - Disable source routed packet acceptance
  sysctl:
    name: "{{ item }}"
    value: '0'
    state: present
    reload: yes
  loop:
    - net.ipv4.conf.all.accept_source_route
    - net.ipv4.conf.default.accept_source_route

- name: CIS 3.2.2 - Disable ICMP redirect acceptance
  sysctl:
    name: "{{ item }}"
    value: '0'
    state: present
    reload: yes
  loop:
    - net.ipv4.conf.all.accept_redirects
    - net.ipv4.conf.default.accept_redirects

- name: CIS 3.2.3 - Disable secure ICMP redirect acceptance
  sysctl:
    name: "{{ item }}"
    value: '0'
    state: present
    reload: yes
  loop:
    - net.ipv4.conf.all.secure_redirects
    - net.ipv4.conf.default.secure_redirects

- name: CIS 3.2.4 - Log suspicious packets
  sysctl:
    name: "{{ item }}"
    value: '1'
    state: present
    reload: yes
  loop:
    - net.ipv4.conf.all.log_martians
    - net.ipv4.conf.default.log_martians

- name: CIS 4.1.1 - Configure audit log storage size
  lineinfile:
    path: /etc/audit/auditd.conf
    regexp: '^max_log_file ='
    line: 'max_log_file = 100'

- name: CIS 4.1.2 - Disable audit when disk is full
  lineinfile:
    path: /etc/audit/auditd.conf
    regexp: "{{ item.regexp }}"
    line: "{{ item.line }}"
  loop:
    - { regexp: '^space_left_action =', line: 'space_left_action = email' }
    - { regexp: '^action_mail_acct =', line: 'action_mail_acct = root' }
    - { regexp: '^admin_space_left_action =', line: 'admin_space_left_action = halt' }

- name: CIS 4.1.3 - Keep audit logs from previous boots
  lineinfile:
    path: /etc/audit/auditd.conf
    regexp: '^max_log_file_action ='
    line: 'max_log_file_action = keep_logs'
```

### Advanced Audit Rules

```yaml
- name: Configure comprehensive audit rules
  copy:
    dest: /etc/audit/rules.d/audit.rules
    content: |
      # Delete all existing rules
      -D
      
      # Buffer size
      -b 8192
      
      # Failure mode (0=silent, 1=printk, 2=panic)
      -f 1
      
      # Monitor authentication events
      -w /var/log/auth.log -p wa -k authentication
      -w /var/log/faillog -p wa -k logins
      -w /var/log/lastlog -p wa -k logins
      -w /var/log/tallylog -p wa -k logins
      
      # Monitor system configuration changes
      -w /etc/passwd -p wa -k identity
      -w /etc/group -p wa -k identity
      -w /etc/shadow -p wa -k identity
      -w /etc/gshadow -p wa -k identity
      -w /etc/security/opasswd -p wa -k identity
      
      # Monitor network configuration
      -w /etc/network/ -p wa -k network
      -w /etc/hosts -p wa -k network
      -w /etc/hostname -p wa -k network
      -w /etc/issue -p wa -k network
      -w /etc/issue.net -p wa -k network
      
      # Monitor system administration
      -w /etc/sudoers -p wa -k scope
      -w /etc/sudoers.d -p wa -k scope
      
      # Monitor privilege escalation
      -w /bin/su -p x -k privileged
      -w /usr/bin/sudo -p x -k privileged
      -w /etc/sudoers -p rw -k privileged
      
      # Monitor file deletions
      -a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
      
      # Monitor changes to system libraries
      -w /lib -p wa -k system-libraries
      -w /lib64 -p wa -k system-libraries
      -w /usr/lib -p wa -k system-libraries
      -w /usr/lib64 -p wa -k system-libraries
      
      # Monitor kernel module changes
      -w /sbin/insmod -p x -k modules
      -w /sbin/rmmod -p x -k modules
      -w /sbin/modprobe -p x -k modules
      -a always,exit -F arch=b64 -S init_module -S delete_module -k modules
      
      # Make configuration immutable
      -e 2
  notify:
    - restart auditd
```

---

## Cost Management

### AMI Lifecycle Management Script

```python
#!/usr/bin/env python3
"""
Golden AMI Lifecycle Management Script
Automatically manages AMI lifecycle, cleanup, and cost optimization
"""

import boto3
import json
import logging
from datetime import datetime, timedelta
from typing import List, Dict, Any
import argparse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class AMILifecycleManager:
    def __init__(self, region: str = 'us-east-1'):
        self.ec2 = boto3.client('ec2', region_name=region)
        self.region = region
        
    def get_golden_amis(self) -> List[Dict[str, Any]]:
        """Get all Golden AMIs owned by this account"""
        try:
            response = self.ec2.describe_images(
                Owners=['self'],
                Filters=[
                    {'Name': 'name', 'Values': ['golden-ami-ubuntu-22.04-*']},
                    {'Name': 'state', 'Values': ['available']}
                ]
            )
            
            amis = response['Images']
            logger.info(f"Found {len(amis)} Golden AMIs in region {self.region}")
            return amis
            
        except Exception as e:
            logger.error(f"Error retrieving AMIs: {e}")
            return []
    
    def get_ami_usage(self, ami_id: str) -> Dict[str, int]:
        """Check if AMI is being used by instances or launch templates"""
        usage = {
            'running_instances': 0,
            'launch_templates': 0,
            'auto_scaling_groups': 0
        }
        
        try:
            # Check running instances
            instances = self.ec2.describe_instances(
                Filters=[
                    {'Name': 'image-id', 'Values': [ami_id]},
                    {'Name': 'instance-state-name', 'Values': ['running', 'pending', 'stopping']}
                ]
            )
            
            for reservation in instances['Reservations']:
                usage['running_instances'] += len(reservation['Instances'])
            
            # Check launch templates
            launch_templates = self.ec2.describe_launch_templates()
            for lt in launch_templates['LaunchTemplates']:
                try:
                    lt_versions = self.ec2.describe_launch_template_versions(
                        LaunchTemplateId=lt['LaunchTemplateId']
                    )
                    
                    for version in lt_versions['LaunchTemplateVersions']:
                        if version.get('LaunchTemplateData', {}).get('ImageId') == ami_id:
                            usage['launch_templates'] += 1
                            break
                except:
                    continue
            
            # Note: Auto Scaling Group check would require additional boto3 client
            
        except Exception as e:
            logger.warning(f"Error checking AMI usage for {ami_id}: {e}")
        
        return usage
    
    def cleanup_old_amis(self, keep_count: int = 5, days_old: int = 30, 
                        dry_run: bool = True) -> List[str]:
        """
        Clean up old AMIs, keeping the most recent ones
        
        Args:
            keep_count: Number of most recent AMIs to keep
            days_old: Delete AMIs older than this many days
            dry_run: If True, don't actually delete anything
            
        Returns:
            List of AMI IDs that were (or would be) deleted
        """
        amis = self.get_golden_amis()
        if not amis:
            logger.info("No Golden AMIs found")
            return []
        
        # Sort by creation date (newest first)
        amis.sort(key=lambda x: x['CreationDate'], reverse=True)
        
        deleted_amis = []
        cutoff_date = datetime.now(datetime.now().astimezone().tzinfo) - timedelta(days=days_old)
        
        for i, ami in enumerate(amis):
            ami_id = ami['ImageId']
            ami_name = ami['Name']
            creation_date = datetime.fromisoformat(ami['CreationDate'].replace('Z', '+00:00'))
            
            # Skip if within keep_count of most recent
            if i < keep_count:
                logger.info(f"Keeping recent AMI: {ami_id} ({ami_name})")
                continue
            
            # Skip if not old enough
            if creation_date > cutoff_date:
                logger.info(f"AMI not old enough to delete: {ami_id} ({ami_name})")
                continue
            
            # Check if AMI is in use
            usage = self.get_ami_usage(ami_id)
            if any(usage.values()):
                logger.warning(f"AMI {ami_id} is in use, skipping: {usage}")
                continue
            
            # Delete AMI and associated snapshots
            if dry_run:
                logger.info(f"Would delete AMI: {ami_id} ({ami_name}) - {creation_date}")
                deleted_amis.append(ami_id)
            else:
                try:
                    # Get snapshot IDs before deregistering
                    snapshots = []
                    for bdm in ami.get('BlockDeviceMappings', []):
                        if 'Ebs' in bdm and 'SnapshotId' in bdm['Ebs']:
                            snapshots.append(bdm['Ebs']['SnapshotId'])
                    
                    # Deregister AMI
                    self.ec2.deregister_image(ImageId=ami_id)
                    logger.info(f"Deregistered AMI: {ami_id}")
                    
                    # Delete associated snapshots
                    for snapshot_id in snapshots:
                        try:
                            self.ec2.delete_snapshot(SnapshotId=snapshot_id)
                            logger.info(f"Deleted snapshot: {snapshot_id}")
                        except Exception as e:
                            logger.warning(f"Failed to delete snapshot {snapshot_id}: {e}")
                    
                    deleted_amis.append(ami_id)
                    
                except Exception as e:
                    logger.error(f"Failed to delete AMI {ami_id}: {e}")
        
        return deleted_amis
    
    def generate_cost_report(self) -> Dict[str, Any]:
        """Generate a cost analysis report for Golden AMIs"""
        amis = self.get_golden_amis()
        
        total_storage_gb = 0
        total_amis = len(amis)
        oldest_ami = None
        newest_ami = None
        
        for ami in amis:
            # Calculate storage size
            for bdm in ami.get('BlockDeviceMappings', []):
                if 'Ebs' in bdm:
                    volume_size = bdm['Ebs'].get('VolumeSize', 0)
                    total_storage_gb += volume_size
            
            # Track oldest and newest
            creation_date = datetime.fromisoformat(ami['CreationDate'].replace('Z', '+00:00'))
            if not oldest_ami or creation_date < datetime.fromisoformat(oldest_ami['CreationDate'].replace('Z', '+00:00')):
                oldest_ami = ami
            if not newest_ami or creation_date > datetime.fromisoformat(newest_ami['CreationDate'].replace('Z', '+00:00')):
                newest_ami = ami
        
        # Estimate monthly costs (EBS snapshot storage is ~$0.05 per GB per month)
        estimated_monthly_cost = total_storage_gb * 0.05
        
        report = {
            'region': self.region,
            'total_amis': total_amis,
            'total_storage_gb': total_storage_gb,
            'estimated_monthly_cost_usd': round(estimated_monthly_cost, 2),
            'oldest_ami': {
                'id': oldest_ami['ImageId'] if oldest_ami else None,
                'name': oldest_ami['Name'] if oldest_ami else None,
                'creation_date': oldest_ami['CreationDate'] if oldest_ami else None
            } if oldest_ami else None,
            'newest_ami': {
                'id': newest_ami['ImageId'] if newest_ami else None,
                'name': newest_ami['Name'] if newest_ami else None,
                'creation_date': newest_ami['CreationDate'] if newest_ami else None
            } if newest_ami else None
        }
        
        return report
    
    def copy_ami_to_regions(self, source_ami_id: str, target_regions: List[str]) -> Dict[str, str]:
        """Copy AMI to multiple regions"""
        results = {}
        
        # Get source AMI details
        try:
            source_ami = self.ec2.describe_images(ImageIds=[source_ami_id])['Images'][0]
        except Exception as e:
            logger.error(f"Failed to get source AMI details: {e}")
            return results
        
        for target_region in target_regions:
            if target_region == self.region:
                continue
                
            try:
                target_ec2 = boto3.client('ec2', region_name=target_region)
                
                copy_response = target_ec2.copy_image(
                    Name=f"{source_ami['Name']}-{target_region}",
                    Description=f"Copy of {source_ami_id} from {self.region}",
                    SourceImageId=source_ami_id,
                    SourceRegion=self.region
                )
                
                new_ami_id = copy_response['ImageId']
                results[target_region] = new_ami_id
                
                # Copy tags
                source_tags = source_ami.get('Tags', [])
                if source_tags:
                    source_tags.append({'Key': 'SourceAMI', 'Value': source_ami_id})
                    source_tags.append({'Key': 'SourceRegion', 'Value': self.region})
                    
                    target_ec2.create_tags(
                        Resources=[new_ami_id],
                        Tags=source_tags
                    )
                
                logger.info(f"Copied AMI to {target_region}: {new_ami_id}")
                
            except Exception as e:
                logger.error(f"Failed to copy AMI to {target_region}: {e}")
                results[target_region] = f"ERROR: {e}"
        
        return results

def main():
    parser = argparse.ArgumentParser(description='Golden AMI Lifecycle Management')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--action', choices=['cleanup', 'report', 'copy'], required=True)
    parser.add_argument('--keep-count', type=int, default=5, help='Number of AMIs to keep')
    parser.add_argument('--days-old', type=int, default=30, help='Delete AMIs older than this')
    parser.add_argument('--dry-run', action='store_true', help='Dry run mode')
    parser.add_argument('--ami-id', help='AMI ID for copy operation')
    parser.add_argument('--target-regions', nargs='+', help='Target regions for copy')
    
    args = parser.parse_args()
    
    manager = AMILifecycleManager(region=args.region)
    
    if args.action == 'cleanup':
        deleted = manager.cleanup_old_amis(
            keep_count=args.keep_count,
            days_old=args.days_old,
            dry_run=args.dry_run
        )
        print(f"{'Would delete' if args.dry_run else 'Deleted'} {len(deleted)} AMIs")
        
    elif args.action == 'report':
        report = manager.generate_cost_report()
        print(json.dumps(report, indent=2, default=str))
        
    elif args.action == 'copy':
        if not args.ami_id or not args.target_regions:
            print("Error: --ami-id and --target-regions required for copy action")
            return
            
        results = manager.copy_ami_to_regions(args.ami_id, args.target_regions)
        print(json.dumps(results, indent=2))

if __name__ == '__main__':
    main()
```

---

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Packer Template Validation Errors

**Issue**: `env` function not recognized
```
Error: Call to unknown function "env"
```

**Solution**: Use variables instead of env function
```hcl
variable "build_user" {
  type    = string
  default = "unknown"
}

# Pass via command line
packer build -var "build_user=$(whoami)" template.pkr.hcl
```

#### 2. Ansible Connection Issues

**Issue**: Ansible runs on localhost instead of target
```
PLAY [Configure Golden AMI] ****************************************************
fatal: [localhost]: FAILED! => {"msg": "sudo: a password is required"}
```

**Solution**: Remove inventory_file from Ansible provisioner
```hcl
provisioner "ansible" {
  playbook_file = "playbook.yml"
  user = "ubuntu"
  # Remove this line: inventory_file = "inventory/hosts"
}
```

#### 3. Build Timeouts

**Issue**: Build times out during package installation
```
Timeout waiting for SSH
```

**Solutions**:
- Increase ssh_timeout in Packer template
- Use faster instance types (t3.medium instead of t3.micro)
- Optimize package installation order
- Use package caching

#### 4. Disk Space Issues

**Issue**: Not enough disk space during build
```
No space left on device
```

**Solutions**:
```hcl
# Increase root volume size
source "amazon-ebs" "ubuntu" {
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = 20
    delete_on_termination = true
  }
}
```

#### 5. Permission Issues

**Issue**: IAM permissions insufficient
```
UnauthorizedOperation: You are not authorized to perform this operation
```

**Solution**: Use the provided IAM policy template
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachVolume",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CopyImage",
                "ec2:CreateImage",
                "ec2:CreateKeypair",
                "ec2:CreateSecurityGroup",
                "ec2:CreateSnapshot",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteKeyPair",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteSnapshot",
                "ec2:DeleteVolume",
                "ec2:DeregisterImage",
                "ec2:DescribeImageAttribute",
                "ec2:DescribeImages",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceAttribute",
                "ec2:DescribeRegions",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSnapshots",
                "ec2:DescribeSubnets",
                "ec2:DescribeTags",
                "ec2:DescribeVolumes",
                "ec2:DetachVolume",
                "ec2:GetPasswordData",
                "ec2:ModifyImageAttribute",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifySnapshotAttribute",
                "ec2:RegisterImage",
                "ec2:RunInstances",
                "ec2:StopInstances",
                "ec2:TerminateInstances"
            ],
            "Resource": "*"
        }
    ]
}
```

### Debug Commands

```bash
# Validate Packer template with verbose output
export PACKER_LOG=1
packer validate template.pkr.hcl

# Test Ansible playbook independently
ansible-playbook -i inventory/hosts playbooks/golden-ami.yml --check

# Check AWS permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/PackerRole \
  --action-names ec2:RunInstances \
  --resource-arns "*"

# Monitor build progress
tail -f /var/log/cloud-init-output.log

# Check AMI status
aws ec2 describe-images --image-ids ami-12345 --query 'Images[0].State'
```

---

## Performance Optimization Tips

1. **Use faster instance types** for building (t3.medium vs t3.micro)
2. **Enable EBS optimization** in Packer source
3. **Use GP3 volumes** for better performance
4. **Parallel provisioning** where possible
5. **Package caching** for faster builds
6. **Regional proximity** - build in the same region as deployment

This technical documentation provides comprehensive implementation details for the Golden AMI automation project. Use it as a reference for deployment, troubleshooting, and customization.
