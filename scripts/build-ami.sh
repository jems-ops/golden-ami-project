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
