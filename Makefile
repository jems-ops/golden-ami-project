.PHONY: help validate build validate-ami clean install lint format

# Default target
help: ## Display this help message
	@echo "Golden AMI Project - Available commands:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo
	@echo "Environment variables:"
	@echo "  ENV          - Environment (production, staging, development) [default: production]"
	@echo "  REGION       - AWS region [default: us-east-1]"
	@echo "  INSTANCE_TYPE - EC2 instance type for building [default: t3.medium]"

# Configuration
ENV ?= production
REGION ?= us-east-1
INSTANCE_TYPE ?= t3.medium

# Directories
PACKER_DIR = packer
ANSIBLE_DIR = ansible
SCRIPTS_DIR = scripts
LOGS_DIR = logs

install: ## Install required dependencies
	@echo "Installing dependencies..."
	@command -v packer >/dev/null 2>&1 || (echo "Error: Packer is not installed" && exit 1)
	@command -v ansible >/dev/null 2>&1 || (echo "Error: Ansible is not installed" && exit 1)
	@command -v aws >/dev/null 2>&1 || (echo "Error: AWS CLI is not installed" && exit 1)
	@command -v jq >/dev/null 2>&1 || (echo "Error: jq is not installed" && exit 1)
	@echo "✅ All dependencies are installed"

validate: validate-packer validate-ansible ## Validate all templates and playbooks

validate-packer: ## Validate Packer template
	@echo "Validating Packer template..."
	@cd $(PACKER_DIR) && packer validate \
		-var "environment=$(ENV)" \
		-var "aws_region=$(REGION)" \
		-var "instance_type=$(INSTANCE_TYPE)" \
		golden-ami.pkr.hcl
	@echo "✅ Packer template validation passed"

validate-ansible: ## Validate Ansible playbook
	@echo "Validating Ansible playbook..."
	@cd $(ANSIBLE_DIR) && ansible-playbook --syntax-check playbooks/golden-ami.yml
	@echo "✅ Ansible playbook validation passed"

lint: lint-ansible ## Run linting on all files

lint-ansible: ## Lint Ansible playbook
	@echo "Linting Ansible playbook..."
	@command -v ansible-lint >/dev/null 2>&1 || pip install ansible-lint
	@cd $(ANSIBLE_DIR) && ansible-lint playbooks/golden-ami.yml || true

format: ## Format shell scripts
	@echo "Formatting shell scripts..."
	@find $(SCRIPTS_DIR) -name "*.sh" -exec shfmt -w {} + || echo "shfmt not installed, skipping formatting"

init: ## Initialize Packer plugins
	@echo "Initializing Packer plugins..."
	@cd $(PACKER_DIR) && packer init .
	@echo "✅ Packer plugins initialized"

build: validate init ## Build the golden AMI
	@echo "Building golden AMI for environment: $(ENV), region: $(REGION)"
	@chmod +x $(SCRIPTS_DIR)/build-ami.sh
	@$(SCRIPTS_DIR)/build-ami.sh $(ENV) $(REGION)

build-dev: ## Build AMI for development environment
	@$(MAKE) build ENV=development

build-staging: ## Build AMI for staging environment
	@$(MAKE) build ENV=staging

build-prod: ## Build AMI for production environment  
	@$(MAKE) build ENV=production

validate-ami: ## Validate the last built AMI
	@if [ ! -f "$(LOGS_DIR)/last-build-$(ENV).json" ]; then \
		echo "❌ No build found for environment $(ENV)"; \
		echo "Run 'make build' first"; \
		exit 1; \
	fi
	@AMI_ID=$$(jq -r '.ami_id' $(LOGS_DIR)/last-build-$(ENV).json); \
	AMI_REGION=$$(jq -r '.region' $(LOGS_DIR)/last-build-$(ENV).json); \
	echo "Validating AMI: $$AMI_ID in region: $$AMI_REGION"; \
	chmod +x $(SCRIPTS_DIR)/validate-ami.sh; \
	$(SCRIPTS_DIR)/validate-ami.sh $$AMI_ID $$AMI_REGION

test: ## Run basic smoke tests
	@echo "Running smoke tests..."
	@$(MAKE) validate
	@echo "Checking AWS credentials..."
	@aws sts get-caller-identity >/dev/null
	@echo "✅ Smoke tests passed"

logs: ## Show the latest build log
	@if [ -f "$(LOGS_DIR)/last-build-$(ENV).json" ]; then \
		LOG_FILE=$$(jq -r '.log_file' $(LOGS_DIR)/last-build-$(ENV).json); \
		echo "Latest build log for $(ENV): $$LOG_FILE"; \
		tail -n 50 "$$LOG_FILE" || echo "Log file not found"; \
	else \
		echo "No build log found for environment $(ENV)"; \
	fi

status: ## Show the status of the last build
	@if [ -f "$(LOGS_DIR)/last-build-$(ENV).json" ]; then \
		echo "Last build status for $(ENV):"; \
		cat $(LOGS_DIR)/last-build-$(ENV).json | jq .; \
	else \
		echo "No build found for environment $(ENV)"; \
	fi

clean: ## Clean build artifacts and logs
	@echo "Cleaning build artifacts..."
	@rm -rf $(LOGS_DIR)/*
	@rm -f $(PACKER_DIR)/manifest.json
	@rm -f $(PACKER_DIR)/*.log
	@echo "✅ Build artifacts cleaned"

clean-logs: ## Clean only log files
	@echo "Cleaning log files..."
	@rm -rf $(LOGS_DIR)/*
	@echo "✅ Log files cleaned"

list-amis: ## List recent golden AMIs
	@echo "Listing recent golden AMIs in region $(REGION)..."
	@aws ec2 describe-images \
		--region $(REGION) \
		--owners self \
		--filters "Name=name,Values=golden-ami-ubuntu-*" \
		--query 'Images[*].[Name,ImageId,CreationDate,State]' \
		--output table || echo "Failed to list AMIs"

setup-iam: ## Deploy IAM roles using CloudFormation
	@echo "Deploying IAM roles and policies..."
	@aws cloudformation create-stack \
		--stack-name packer-iam-roles \
		--template-body file://policies/iam-roles.yml \
		--capabilities CAPABILITY_NAMED_IAM \
		--region $(REGION) || \
	aws cloudformation update-stack \
		--stack-name packer-iam-roles \
		--template-body file://policies/iam-roles.yml \
		--capabilities CAPABILITY_NAMED_IAM \
		--region $(REGION) || echo "IAM stack deployment failed"

info: ## Show project information
	@echo "Golden AMI Project Information:"
	@echo "  Environment: $(ENV)"
	@echo "  Region: $(REGION)"
	@echo "  Instance Type: $(INSTANCE_TYPE)"
	@echo
	@echo "Project structure:"
	@tree -L 2 . 2>/dev/null || find . -type d -maxdepth 2 | head -20

# Docker targets (if using Docker for builds)
docker-build: ## Build AMI using Docker container
	@echo "Building AMI using Docker..."
	@docker run --rm \
		-v $(PWD):/workspace \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_DEFAULT_REGION=$(REGION) \
		-w /workspace \
		hashicorp/packer:latest \
		build -var "environment=$(ENV)" -var "aws_region=$(REGION)" packer/golden-ami.pkr.hcl

# Development targets
dev-setup: install init ## Setup development environment
	@echo "Setting up development environment..."
	@$(MAKE) validate
	@echo "✅ Development environment setup complete"

# CI/CD targets
ci-validate: ## CI validation (no AWS calls)
	@echo "Running CI validation..."
	@$(MAKE) validate-packer validate-ansible lint
	@echo "✅ CI validation passed"

ci-build: ## CI build process
	@echo "Running CI build process..."
	@$(MAKE) install validate init build validate-ami
	@echo "✅ CI build process completed"
