#!/bin/bash

set -euo pipefail

# AMI Validation Script
# Usage: ./validate-ami.sh [AMI_ID] [REGION]

# Check if AMI ID is provided
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <AMI_ID> [REGION]"
    echo "Example: $0 ami-1234567890abcdef0 us-west-2"
    exit 1
fi

AMI_ID="$1"
REGION="${2:-us-west-2}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $*"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*"
}

# Validation functions
validate_ami_exists() {
    log "Checking if AMI exists and is available..."
    
    local ami_info
    ami_info=$(aws ec2 describe-images \
        --region "$REGION" \
        --image-ids "$AMI_ID" \
        --query 'Images[0]' \
        --output json 2>/dev/null || echo "null")
    
    if [[ "$ami_info" == "null" ]]; then
        error "AMI $AMI_ID not found in region $REGION"
        return 1
    fi
    
    local state
    state=$(echo "$ami_info" | jq -r '.State')
    
    if [[ "$state" == "available" ]]; then
        success "AMI $AMI_ID is available"
        
        # Display AMI information
        log "AMI Details:"
        echo "$ami_info" | jq -r '
            "  Name: " + .Name,
            "  Description: " + (.Description // "N/A"),
            "  Architecture: " + .Architecture,
            "  Root Device Type: " + .RootDeviceType,
            "  Virtualization Type: " + .VirtualizationType,
            "  Creation Date: " + .CreationDate,
            "  Owner: " + .OwnerId,
            "  Public: " + (.Public | tostring)'
        
        return 0
    else
        error "AMI $AMI_ID is in state: $state"
        return 1
    fi
}

validate_ami_tags() {
    log "Validating AMI tags..."
    
    local tags
    tags=$(aws ec2 describe-images \
        --region "$REGION" \
        --image-ids "$AMI_ID" \
        --query 'Images[0].Tags' \
        --output json)
    
    if [[ "$tags" == "null" || "$tags" == "[]" ]]; then
        warning "AMI has no tags"
        return 1
    fi
    
    success "AMI has the following tags:"
    echo "$tags" | jq -r '.[] | "  " + .Key + ": " + .Value'
    
    # Check for recommended tags
    local required_tags=("Name" "Environment" "Purpose")
    local missing_tags=()
    
    for tag in "${required_tags[@]}"; do
        if ! echo "$tags" | jq -r '.[].Key' | grep -q "^$tag$"; then
            missing_tags+=("$tag")
        fi
    done
    
    if [[ ${#missing_tags[@]} -gt 0 ]]; then
        warning "Missing recommended tags: ${missing_tags[*]}"
    else
        success "All recommended tags are present"
    fi
    
    return 0
}

launch_test_instance() {
    log "Launching test instance from AMI..."
    
    # Get default VPC and subnet
    local vpc_id
    vpc_id=$(aws ec2 describe-vpcs \
        --region "$REGION" \
        --filters "Name=is-default,Values=true" \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null || echo "None")
    
    if [[ "$vpc_id" == "None" ]]; then
        warning "No default VPC found. Skipping instance launch test."
        return 1
    fi
    
    local subnet_id
    subnet_id=$(aws ec2 describe-subnets \
        --region "$REGION" \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=default-for-az,Values=true" \
        --query 'Subnets[0].SubnetId' \
        --output text)
    
    # Create security group for testing
    local sg_id
    sg_id=$(aws ec2 create-security-group \
        --region "$REGION" \
        --group-name "ami-validation-$(date +%s)" \
        --description "Temporary security group for AMI validation" \
        --vpc-id "$vpc_id" \
        --query 'GroupId' \
        --output text)
    
    # Add SSH rule
    aws ec2 authorize-security-group-ingress \
        --region "$REGION" \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 >/dev/null
    
    log "Created temporary security group: $sg_id"
    
    # Launch instance
    local instance_id
    instance_id=$(aws ec2 run-instances \
        --region "$REGION" \
        --image-id "$AMI_ID" \
        --instance-type t3.micro \
        --subnet-id "$subnet_id" \
        --security-group-ids "$sg_id" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=AMI-Validation-Test},{Key=Purpose,Value=Testing}]" \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    log "Launched test instance: $instance_id"
    
    # Wait for instance to be running
    log "Waiting for instance to be in running state..."
    aws ec2 wait instance-running \
        --region "$REGION" \
        --instance-ids "$instance_id"
    
    # Get instance details
    local instance_info
    instance_info=$(aws ec2 describe-instances \
        --region "$REGION" \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0]')
    
    local public_ip
    public_ip=$(echo "$instance_info" | jq -r '.PublicIpAddress // "N/A"')
    
    local private_ip
    private_ip=$(echo "$instance_info" | jq -r '.PrivateIpAddress')
    
    success "Test instance is running"
    log "Instance Details:"
    log "  Instance ID: $instance_id"
    log "  Public IP: $public_ip"
    log "  Private IP: $private_ip"
    
    # Wait a bit for the instance to fully boot
    log "Waiting 60 seconds for instance to fully boot..."
    sleep 60
    
    # Try to get system information (if we have key pair access)
    log "Instance launched successfully from AMI $AMI_ID"
    
    # Cleanup
    log "Cleaning up test resources..."
    
    # Terminate instance
    aws ec2 terminate-instances \
        --region "$REGION" \
        --instance-ids "$instance_id" >/dev/null
    
    # Wait for termination
    aws ec2 wait instance-terminated \
        --region "$REGION" \
        --instance-ids "$instance_id"
    
    # Delete security group
    aws ec2 delete-security-group \
        --region "$REGION" \
        --group-id "$sg_id"
    
    success "Test instance terminated and resources cleaned up"
    
    return 0
}

validate_ami_permissions() {
    log "Checking AMI permissions..."
    
    local launch_permissions
    launch_permissions=$(aws ec2 describe-image-attribute \
        --region "$REGION" \
        --image-id "$AMI_ID" \
        --attribute launchPermission \
        --query 'LaunchPermissions' \
        --output json)
    
    if [[ "$launch_permissions" == "[]" ]]; then
        log "AMI is private (no additional launch permissions)"
    else
        warning "AMI has additional launch permissions:"
        echo "$launch_permissions" | jq .
    fi
    
    return 0
}

# Main validation function
main() {
    log "Starting AMI validation for $AMI_ID in region $REGION"
    
    local validation_passed=true
    
    # Run all validation checks
    if ! validate_ami_exists; then
        validation_passed=false
    fi
    
    if ! validate_ami_tags; then
        validation_passed=false
    fi
    
    if ! validate_ami_permissions; then
        validation_passed=false
    fi
    
    # Optional: Launch test instance
    read -p "Do you want to launch a test instance from this AMI? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! launch_test_instance; then
            warning "Test instance launch failed or was skipped"
        fi
    fi
    
    # Summary
    log ""
    if [[ "$validation_passed" == true ]]; then
        success "AMI validation completed successfully!"
        log "AMI $AMI_ID appears to be valid and ready for use."
    else
        error "AMI validation completed with issues!"
        log "Please review the warnings and errors above."
        exit 1
    fi
}

# Handle script interruption
trap 'error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"
